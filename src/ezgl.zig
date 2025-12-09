const std = @import("std");

const gl = @import("gl");
const gltf = @import("gltf");
const ezmath = @import("ezmath");
const c = @cImport({
    @cInclude("ktx.h");
});

pub const ShaderType = enum(c_uint) {
    compute_shader = gl.COMPUTE_SHADER,
    vertex_shader = gl.VERTEX_SHADER,
    tess_control_shader = gl.TESS_CONTROL_SHADER,
    tess_evaluation_shader = gl.TESS_EVALUATION_SHADER,
    geometry_shader = gl.GEOMETRY_SHADER,
    fragment_shader = gl.FRAGMENT_SHADER,
};

const ShaderFileList = struct {
    types: []const ShaderType,
    paths: []const []const u8,
};

const Errors = error{ GlCompileShaderFailed, GlCreateShaderFailed, GlCreateProgramFailed, GlShaderAlreadyAttached };

const GlErrors = error{
    NoError,
    InvalidEnum,
    InvalidValue,
    InvlaidOperation,
    InvalidFramebufferOperation,
    OutofMemory,
    StackUnderflow,
    StackOverflow,
};

/// Returns a reference to a compiled shader, you must delete the shader after calling
pub fn createAndCompileShader(shader_type: ShaderType, shader_file_path: []const u8, allocator: std.mem.Allocator, io: std.Io) !gl.uint {
    var success: c_int = undefined;
    var info_log_buf: [512:0]u8 = undefined;
    const shader_source = try loadFileFromPath(shader_file_path, allocator, io);

    const shader: gl.uint = gl.CreateShader(@intFromEnum(shader_type));
    if (shader == 0) return Errors.GlCreateShaderFailed;

    gl.ShaderSource(shader, 1, &.{@ptrCast(shader_source)}, null);
    gl.CompileShader(shader);
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, (&success)[0..1]);

    if (success == gl.FALSE) {
        gl.GetShaderInfoLog(shader, info_log_buf.len, null, &info_log_buf);
        std.debug.print("{s}\n", .{std.mem.sliceTo(&info_log_buf, 0)});
        return Errors.GlCompileShaderFailed;
    }

    return shader;
}

/// Creates an openGL program will allocate temp memory on the heap
pub fn createProgramAndLinkShaders(shader_files: ShaderFileList) !gl.uint {
    // TODO: Deal with threading
    var threaded: std.Io.Threaded = .init_single_threaded;

    const io = threaded.ioBasic();
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();
    var success: c_int = undefined;
    var info_log_buf: [512:0]u8 = undefined;

    const program: gl.uint = gl.CreateProgram();
    if (program == 0) return Errors.GlCreateProgramFailed;

    for (shader_files.types, shader_files.paths) |shader_type, path| {
        const shader = try createAndCompileShader(shader_type, path, arena_allocator, io);
        defer gl.DeleteShader(shader);
        gl.AttachShader(program, shader);
        try checkAndReturnError(gl.INVALID_OPERATION, Errors.GlShaderAlreadyAttached);
    }
    gl.LinkProgram(program);
    gl.GetProgramiv(program, gl.LINK_STATUS, (&success)[0..1]);
    if (success == gl.FALSE) {
        gl.GetProgramInfoLog(program, info_log_buf.len, null, &info_log_buf);
        std.debug.print("{s}\n", .{std.mem.sliceTo(&info_log_buf, 0)});
    }

    return program;
}

/// Loads a file from the path as a c string
fn loadFileFromPath(path: []const u8, allocator: std.mem.Allocator, io: std.Io) ![:0]u8 {
    const file = try std.Io.Dir.openFile(std.Io.Dir.cwd(), io, path, .{});
    defer file.close(io);
    const file_info = try file.stat(io);

    const buffer: [:0]u8 = try allocator.allocSentinel(u8, file_info.size, 0);
    _ = try std.Io.Dir.cwd().readFile(io, path, buffer);
    return buffer;
}

/// Reads A GLB file and splits it into the json chunk and the binary chunk
pub fn readGlb(path: []const u8, allocator: std.mem.Allocator, io: std.Io) !GlbData {
    const file = try std.Io.Dir.openFile(std.Io.Dir.cwd(), io, path, .{});
    defer file.close(io);

    var header: [4]u8 = undefined;
    var reader = file.reader(io, &header);

    const magic = try reader.interface.takeInt(u32, std.builtin.Endian.little);
    const version = try reader.interface.takeInt(u32, std.builtin.Endian.little);
    const length = try reader.interface.takeInt(u32, std.builtin.Endian.little);

    if (magic != 0x46546C67) {
        return ParseError.NotGlbFile;
    }
    if (version != 2) {
        return ParseError.IncorrectGltfVersion;
    }

    const first_chunk_length = try reader.interface.takeInt(u32, std.builtin.Endian.little);
    const first_chunk_type = try reader.interface.takeInt(u32, std.builtin.Endian.little);

    if (first_chunk_type != 0x4e4f534a) {
        return ParseError.MalformedGlbFile;
    }

    const json_data = try reader.interface.readAlloc(allocator, first_chunk_length);
    const parsed_json = try std.json.parseFromSlice(gltf.Gltf, allocator, json_data, .{});

    //=== === GLTF has a JSON chunk and Optional Binary Data Chunk 4 Byte Aligned

    const current_position = 12 + 8 + first_chunk_length;
    const padding_bytes = if (current_position % 4 > 0) 4 - (current_position % 4) else 0;

    if (current_position + padding_bytes + 4 >= length) {
        return .{ .json = parsed_json, .bin = null };
    }

    try reader.seekTo(current_position + padding_bytes);

    //=== === This GLB File Has the Binary Data

    const second_chunk_length = try reader.interface.takeInt(u32, std.builtin.Endian.little);
    const second_chunk_type = try reader.interface.takeInt(u32, std.builtin.Endian.little);

    if (second_chunk_type != 0x004e4942) {
        return ParseError.MalformedGlbFile;
    }

    const bin_data = try reader.interface.readAlloc(allocator, second_chunk_length);

    return .{ .json = parsed_json, .bin = bin_data };
}

pub fn renderMesh(data: GlbData, mesh_index: u32, trs_matrix: [16]f32, opt: *RenderOptions) !void {
    if (data.bin == null) return RenderError.NoBufferData;
    const mesh = data.json.value.meshes.?[mesh_index];
    for (mesh.primitives) |primitive| {
        try renderMeshPrimitive(data, primitive, trs_matrix, opt);
    }
}

fn renderMeshPrimitive(data: GlbData, mesh_primitive: gltf.MeshPrimitive, trs_matrix: [16]f32, opt: *RenderOptions) !void {
    gl.UseProgram(opt.program);

    const perspective_matrix_uniform: gl.int = gl.GetUniformLocation(opt.program, "perspective_matrix");
    const trs_matrix_uniform: gl.int = gl.GetUniformLocation(opt.program, "trs_matrix");
    const world_to_camera_uniform: gl.int = gl.GetUniformLocation(opt.program, "world_to_camera");
    const color_uniform: gl.int = gl.GetUniformLocation(opt.program, "color");
    const tex_offset_uniform: gl.int = gl.GetUniformLocation(opt.program, "offset");
    const tex_scale_uniform: gl.int = gl.GetUniformLocation(opt.program, "scale");
    const tex_rot_uniform: gl.int = gl.GetUniformLocation(opt.program, "rot");

    gl.UniformMatrix4fv(perspective_matrix_uniform, 1, gl.FALSE, &.{opt.perspective});
    gl.UniformMatrix4fv(trs_matrix_uniform, 1, gl.FALSE, &.{trs_matrix});
    gl.UniformMatrix4fv(world_to_camera_uniform, 1, gl.FALSE, &.{opt.world_to_camera});
    if (data.json.value.materials != null and mesh_primitive.material != null) {
        gl.Uniform4fv(color_uniform, 1, &.{data.json.value.materials.?[mesh_primitive.material.?].pbrMetallicRoughness.baseColorFactor});
    } else {
        const color = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
        gl.Uniform4fv(color_uniform, 1, &.{color});
    }

    if (data.json.value.materials != null and mesh_primitive.material != null) {
        const texture_info = data.json.value.materials.?[mesh_primitive.material.?].pbrMetallicRoughness.baseColorTexture;

        if (texture_info != null) {
            const texture = data.json.value.textures.?[texture_info.?.index];
            const texture_sampler = if (data.json.value.samplers != null and texture.sampler != null) data.json.value.samplers.?[texture.sampler.?] else null;

            if (texture_info.?.extensions != null and texture_info.?.extensions.?.KHR_texture_transform != null) {
                gl.Uniform2fv(tex_offset_uniform, 1, &.{texture_info.?.extensions.?.KHR_texture_transform.?.offset});
                gl.Uniform2fv(tex_scale_uniform, 1, &.{texture_info.?.extensions.?.KHR_texture_transform.?.scale});
                gl.Uniform1f(tex_rot_uniform, texture_info.?.extensions.?.KHR_texture_transform.?.rotation);
            } else {
                gl.Uniform2f(tex_offset_uniform, 0.0, 0.0);
                gl.Uniform2f(tex_scale_uniform, 1.0, 1.0);
                gl.Uniform1f(tex_rot_uniform, 0.0);
            }

            if (texture.extensions != null and texture.extensions.?.KHR_texture_basisu != null) {
                const image = data.json.value.images.?[texture.extensions.?.KHR_texture_basisu.?.source];
                if (image.bufferView != null) {
                    // TODO: IF I USE MORPH TARGETS I NEED TO DEQUANTIZE THIS / SAME WITH ACCESSOR MIN / MAX

                    gl.BindTexture(texture.extras.?.uploadedTexture.?.target, texture.extras.?.uploadedTexture.?.texture);
                    gl.TexParameteri(texture.extras.?.uploadedTexture.?.target, gl.TEXTURE_WRAP_S, if (texture_sampler != null) @intCast(texture_sampler.?.wrapS) else gl.REPEAT);
                    gl.TexParameteri(texture.extras.?.uploadedTexture.?.target, gl.TEXTURE_WRAP_T, if (texture_sampler != null) @intCast(texture_sampler.?.wrapT) else gl.REPEAT);
                    gl.TexParameteri(texture.extras.?.uploadedTexture.?.target, gl.TEXTURE_MAG_FILTER, if (texture_sampler != null and texture_sampler.?.magFilter != null) @intCast(texture_sampler.?.magFilter.?) else gl.LINEAR);
                    gl.TexParameteri(texture.extras.?.uploadedTexture.?.target, gl.TEXTURE_MIN_FILTER, if (texture_sampler != null and texture_sampler.?.minFilter != null) @intCast(texture_sampler.?.minFilter.?) else gl.LINEAR_MIPMAP_LINEAR);
                }
            }
        }
    }

    const index_accessor = data.json.value.accessors.?[mesh_primitive.indices.?];

    gl.BindVertexArray(mesh_primitive.extras.?.uploadedPrimitive.?.vao);
    gl.FrontFace(opt.winding_order);
    gl.DrawElements(
        gltfPrimitiveMeshModeToTopologyType(mesh_primitive.mode),
        @intCast(index_accessor.count),
        @intCast(index_accessor.componentType),
        0,
    );
}

pub fn renderGltf(data: GlbData, trs_matrix: [16]f32, opt: *RenderOptions) !void {
    if (data.json.value.scenes == null) return RenderError.NoScenes;
    try renderScene(data, data.json.value.scenes.?[data.json.value.scene orelse 0], trs_matrix, opt);
}

pub fn renderScene(data: GlbData, scene: gltf.Scene, trs_matrix: [16]f32, opt: *RenderOptions) !void {
    if (scene.nodes == null) return RenderError.NoNodes;
    for (scene.nodes.?) |node_index| {
        try renderNode(data, data.json.value.nodes.?[node_index], trs_matrix, opt);
    }
}

fn renderNode(data: GlbData, node: gltf.Node, trs_matrix: [16]f32, opt: *RenderOptions) !void {
    var node_matrix: [16]f32 = undefined;
    if (node.matrix != null) {
        node_matrix = ezmath.matrixCopy(node.matrix.?);
    }
    node_matrix = ezmath.matrixIdentity();
    if (node.translation != null) {
        ezmath.matrixTranslate(&node_matrix, node.translation.?);
    }
    if (node.rotation != null) {
        ezmath.matrixRotate(&node_matrix, node.rotation.?);
    }
    if (node.scale != null) {
        ezmath.matrixScale(&node_matrix, node.scale.?);
    }
    node_matrix = ezmath.matrixMultiplyNew(trs_matrix, node_matrix);

    if (node.children != null) {
        for (node.children.?) |child_index| {
            try renderNode(data, data.json.value.nodes.?[child_index], node_matrix, opt);
        }
    }
    if (node.mesh != null) {
        const det = ezmath.det(node_matrix);
        opt.winding_order = if (det > 0) gl.CCW else gl.CW;
        try renderMesh(data, node.mesh.?, node_matrix, opt);
    }
}

pub fn uploadGltf(data: *GlbData, allocator: std.mem.Allocator) !void {
    try uploadMeshPrimitives(data, allocator);
    try transcodeAndUploadTextures(data);
}

fn uploadMeshPrimitives(data: *GlbData, allocator: std.mem.Allocator) !void {
    for (data.json.value.meshes.?) |*mesh| {
        for (mesh.primitives) |*primitive| {
            if (primitive.extras == null) {
                primitive.extras = .{};
            }
            primitive.extras.?.uploadedPrimitive = try uploadMeshPrimitive(data.*, allocator, primitive.*);
        }
    }
}

fn uploadMeshPrimitive(data: GlbData, allocator: std.mem.Allocator, mesh_primitive: gltf.MeshPrimitive) !UploadedMeshPrimitive {

    // This temp allocates on the heap
    var temp_allocator = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer temp_allocator.deinit();
    const arena = temp_allocator.allocator();
    var uploaded_buffers = std.AutoHashMap(u32, void).init(arena);

    var count: u32 = 0;
    for (mesh_primitive.attributes.map.keys()) |attribute| {
        const shader_location = attributeToShaderLocation(attribute);
        if (shader_location > 6) {
            std.debug.print("Using unknown attribute: {s}\n", .{attribute});
            continue;
        }
        count += 1;
    }

    var vao: gl.uint = undefined;
    gl.GenVertexArrays(1, (&vao)[0..1]);
    // TODO: PUT THIS IN THE DESTORY CODE //defer gl.DeleteVertexArrays(1, (&vao)[0..1]);
    gl.BindVertexArray(vao);

    var vbos = try allocator.alloc(gl.uint, count);

    var vbo: gl.uint = undefined;

    for (mesh_primitive.attributes.map.keys(), mesh_primitive.attributes.map.values(), 0..) |attribute, accessor_location, i| {
        const shader_location = attributeToShaderLocation(attribute);
        if (shader_location > 6) {
            std.debug.print("Using unknown attribute: {s}\n", .{attribute});
            continue;
        }
        // TODO: Add the rest of the accessor options defined in glTF 3.7.2
        // TODO: I might want to investigate generating all buffers on oject load and not each frame

        const accessor = data.json.value.accessors.?[accessor_location];
        const buffer_view = data.json.value.bufferViews.?[accessor.bufferView.?];

        if (!uploaded_buffers.contains(accessor.bufferView.?)) {
            gl.BindBuffer(gl.ARRAY_BUFFER, 0);
            gl.GenBuffers(1, (&vbo)[0..1]);
            gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
            vbos[i] = vbo;

            gl.EnableVertexAttribArray(shader_location);
            gl.VertexAttribPointer(shader_location, gltfTypeToSize(accessor.type), @intCast(accessor.componentType), boolToGlBool(accessor.normalized), @intCast(buffer_view.byteStride orelse 0), accessor.byteOffset);

            gl.BufferData(gl.ARRAY_BUFFER, @intCast(buffer_view.byteLength), &(data.bin.?[buffer_view.byteOffset + accessor.byteOffset]), gl.STATIC_DRAW);

            try uploaded_buffers.put(accessor.bufferView.?, {});
        } else {
            gl.EnableVertexAttribArray(shader_location);
            gl.VertexAttribPointer(shader_location, gltfTypeToSize(accessor.type), @intCast(accessor.componentType), boolToGlBool(accessor.normalized), @intCast(buffer_view.byteStride orelse 0), accessor.byteOffset);
        }
    }

    const index_accessor = data.json.value.accessors.?[mesh_primitive.indices.?];
    const index_buffer_view = data.json.value.bufferViews.?[index_accessor.bufferView.?];

    var ibo: gl.uint = undefined;
    gl.GenBuffers(1, (&ibo)[0..1]);
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo);
    defer gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
    gl.BufferData(
        gl.ELEMENT_ARRAY_BUFFER,
        @intCast(index_buffer_view.byteLength),
        &(data.bin.?[index_buffer_view.byteOffset + index_accessor.byteOffset]),
        gl.STATIC_DRAW,
    );

    gl.BindVertexArray(0);
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
    gl.BindBuffer(gl.ARRAY_BUFFER, 0);

    return .{ .vao = vao, .vbos = vbos, .ibo = ibo };
}

pub fn transcodeAndUploadTextures(data: *GlbData) !void {
    for (data.json.value.textures.?) |*texture| {
        if (texture.extensions == null or texture.extensions.?.KHR_texture_basisu == null) continue;
        var gl_texture: gl.uint = undefined;
        gl.GenTextures(1, (&gl_texture)[0..1]);
        const image_source = data.json.value.images.?[texture.extensions.?.KHR_texture_basisu.?.source];
        const texture_buffer_view = data.json.value.bufferViews.?[image_source.bufferView.?];

        var bc7_texture: *c.ktxTexture2 = undefined;
        _ = c.ktxTexture2_CreateFromMemory(
            data.bin.?.ptr + texture_buffer_view.byteOffset,
            texture_buffer_view.byteLength,
            c.KTX_TEXTURE_CREATE_NO_FLAGS,
            @ptrCast(&bc7_texture),
        );

        _ = c.ktxTexture2_TranscodeBasis(bc7_texture, c.KTX_TTF_BC7_RGBA, 0);

        var target: gl.@"enum" = undefined;
        var glerror: gl.@"enum" = undefined;
        _ = c.ktxTexture_GLUpload(@ptrCast(bc7_texture), &gl_texture, &target, &glerror);
        c.ktxTexture2_Destroy(bc7_texture);

        if (texture.extras == null) {
            texture.extras = .{};
        }
        texture.extras.?.uploadedTexture = .{
            .texture = gl_texture,
            .target = target,
        };
    }
}

fn gltfTypeToSize(gltf_type: []const u8) i32 {
    if (std.mem.eql(u8, gltf_type, "SCALAR")) return 1;
    if (std.mem.eql(u8, gltf_type, "VEC2")) return 2;
    if (std.mem.eql(u8, gltf_type, "VEC3")) return 3;
    if (std.mem.eql(u8, gltf_type, "VEC4")) return 4;
    if (std.mem.eql(u8, gltf_type, "MAT2")) return 4;
    if (std.mem.eql(u8, gltf_type, "MAT3")) return 9;
    if (std.mem.eql(u8, gltf_type, "MAT4")) return 16;
    return 4;
}

fn gltfPrimitiveMeshModeToTopologyType(mode: i64) c_uint {
    return switch (mode) {
        0 => gl.POINTS,
        1 => gl.LINES,
        2 => gl.LINE_LOOP,
        3 => gl.LINE_STRIP,
        4 => gl.TRIANGLES,
        5 => gl.TRIANGLE_STRIP,
        6 => gl.TRIANGLE_FAN,
        else => gl.TRIANGLES,
    };
}

fn boolToGlBool(x: bool) gl.boolean {
    if (x) return gl.TRUE;
    return gl.FALSE;
}

fn attributeToShaderLocation(attribute: []const u8) u32 {
    if (std.mem.eql(u8, attribute, "POSITION")) return 0;
    if (std.mem.eql(u8, attribute, "NORMAL")) return 1;
    if (std.mem.eql(u8, attribute, "TANGENT")) return 2;
    if (std.mem.eql(u8, attribute, "TEXCOORD_0")) return 3;
    if (std.mem.eql(u8, attribute, "TEXCOORD_1")) return 4;
    if (std.mem.eql(u8, attribute, "COLOR_0")) return 5;
    if (std.mem.eql(u8, attribute, "COLOR_1")) return 6;
    return 7;
}

pub fn calcFrustumScale(fov: f32, is_rad: bool) f32 {
    const deg_to_rad = std.math.pi * 2.0 / 360.0;
    const fov_rad = if (is_rad) fov else fov * deg_to_rad;
    return 1.0 / @tan(fov_rad / 2.0);
}

const GlbData = struct {
    json: std.json.Parsed(gltf.Gltf),
    bin: ?[]const u8,
};

pub const RenderOptions = struct {
    program: gl.uint,
    frustum: Frustum,
    perspective: [16]f32,
    winding_order: gl.uint = gl.CCW,
    world_to_camera: [16]f32,
};

pub const RenderContext = struct {
    data: *GlbData,
};

const Frustum = struct {
    scale: f32,
    z_near: f32,
    z_far: f32,
};

pub const UploadedTexture = struct {
    texture: gl.uint,
    target: gl.@"enum",
};

pub const UploadedMeshPrimitive = struct {
    vao: gl.uint,
    vbos: []const gl.uint,
    ibo: gl.uint,
};

const ParseError = error{ NotGlbFile, IncorrectGltfVersion, MalformedGlbFile };

const RenderError = error{
    NoBufferData,
    NoScenes,
    NoNodes,
};

/// Checks all openGl errors for the specified error and returns the specified error if found. error flag will be set to NO_ERROR after calling this
pub fn checkAndReturnError(error_code: c_uint, error_to_return: Errors) !void {
    const err = gl.GetError();
    var found: bool = false;
    var last_err = err;
    while (err != gl.NO_ERROR) {
        if (err == error_code) found = true;
        last_err = err;
    }
    if (found) return error_to_return;
    return switch (last_err) {
        gl.NO_ERROR => {},
        gl.INVALID_ENUM => GlErrors.InvalidEnum,
        gl.INVALID_VALUE => GlErrors.InvalidValue,
        gl.INVALID_OPERATION => GlErrors.InvlaidOperation,
        gl.INVALID_FRAMEBUFFER_OPERATION => GlErrors.InvalidFramebufferOperation,
        gl.OUT_OF_MEMORY => GlErrors.OutofMemory,
        gl.STACK_UNDERFLOW => GlErrors.StackUnderflow,
        gl.STACK_OVERFLOW => GlErrors.StackOverflow,
        else => unreachable,
    };
}
