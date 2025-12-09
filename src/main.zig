const std = @import("std");
const allocater = std.heap.c_allocator;

const gl = @import("gl");

const ezgl = @import("ezgl");
const ezwl = @import("ezwl");
const gltf = @import("gltf");
const ezmath = @import("ezmath");
const c = ezwl.C;

fn errorCallback(err: c_int, description: [*c]const u8) callconv(std.builtin.CallingConvention.c) void {
    std.log.err("GLFW Error: {d} \n{s}\n", .{ err, description });
}

fn keyCallback(window: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(std.builtin.CallingConvention.c) void {
    _ = scancode;
    _ = mods;
    if (key == c.GLFW_KEY_ESCAPE and action == c.GLFW_PRESS) {
        c.glfwSetWindowShouldClose(window, c.GLFW_TRUE);
    }
    if (key == c.GLFW_KEY_W) {
        if (action == c.GLFW_PRESS) {
            move_keys[0] = true;
        }
        if (action == c.GLFW_RELEASE) {
            move_keys[0] = false;
        }
    }
    if (key == c.GLFW_KEY_A) {
        if (action == c.GLFW_PRESS) {
            move_keys[1] = true;
        }
        if (action == c.GLFW_RELEASE) {
            move_keys[1] = false;
        }
    }
    if (key == c.GLFW_KEY_S) {
        if (action == c.GLFW_PRESS) {
            move_keys[2] = true;
        }
        if (action == c.GLFW_RELEASE) {
            move_keys[2] = false;
        }
    }
    if (key == c.GLFW_KEY_D) {
        if (action == c.GLFW_PRESS) {
            move_keys[3] = true;
        }
        if (action == c.GLFW_RELEASE) {
            move_keys[3] = false;
        }
    }
    if (key == c.GLFW_KEY_Q) {
        if (action == c.GLFW_PRESS) {
            move_keys[4] = true;
        }
        if (action == c.GLFW_RELEASE) {
            move_keys[4] = false;
        }
    }
    if (key == c.GLFW_KEY_E) {
        if (action == c.GLFW_PRESS) {
            move_keys[5] = true;
        }
        if (action == c.GLFW_RELEASE) {
            move_keys[5] = false;
        }
    }

    if (key == c.GLFW_KEY_K) {
        if (action == c.GLFW_PRESS) {
            rot_x = true;
        }
        if (action == c.GLFW_RELEASE) {
            rot_x = false;
        }
    }
    if (key == c.GLFW_KEY_L) {
        if (action == c.GLFW_PRESS) {
            rot_y = true;
        }
        if (action == c.GLFW_RELEASE) {
            rot_y = false;
        }
    }
    if (key == c.GLFW_KEY_Y) {
        if (action == c.GLFW_PRESS) {
            rot_z = true;
        }
        if (action == c.GLFW_RELEASE) {
            rot_z = false;
        }
    }

    // Camera Positions
    if (key == c.GLFW_KEY_LEFT) {
        if (action == c.GLFW_PRESS) {
            camera_keys[0] = true;
        } else if (action == c.GLFW_RELEASE) {
            camera_keys[0] = false;
        }
    }
    if (key == c.GLFW_KEY_RIGHT) {
        if (action == c.GLFW_PRESS) {
            camera_keys[1] = true;
        } else if (action == c.GLFW_RELEASE) {
            camera_keys[1] = false;
        }
    }
    if (key == c.GLFW_KEY_UP) {
        if (action == c.GLFW_PRESS) {
            camera_keys[2] = true;
        } else if (action == c.GLFW_RELEASE) {
            camera_keys[2] = false;
        }
    }
    if (key == c.GLFW_KEY_DOWN) {
        if (action == c.GLFW_PRESS) {
            camera_keys[3] = true;
        } else if (action == c.GLFW_RELEASE) {
            camera_keys[3] = false;
        }
    }

    if (key == c.GLFW_KEY_SPACE) {
        if (action == c.GLFW_PRESS) {
            space = true;
        } else if (action == c.GLFW_RELEASE) {
            space = false;
        }
    }
}

var rot_x = false;
var rot_y = false;
var rot_z = false;

var move_keys = [_]bool{false} ** 6;

var camera_keys = [_]bool{false} ** 6;

var space = false;

pub fn main() !void {
    // === === Set up the glfw window and opengl context

    _ = c.glfwSetErrorCallback(errorCallback);

    const window: ?*c.GLFWwindow = try ezwl.createWindowAndSetContext(4, 6, 640, 480, "OpenGL Triangle", null, null);
    defer c.glfwTerminate();
    defer c.glfwDestroyWindow(window);
    defer c.glfwMakeContextCurrent(null);

    _ = c.glfwSetKeyCallback(window, keyCallback);

    // === === Initalize the Procedure Table on the Main Thread

    var gl_procs: gl.ProcTable = undefined;
    if (!gl_procs.init(c.glfwGetProcAddress)) {
        return;
    }

    gl.makeProcTableCurrent(&gl_procs);
    defer gl.makeProcTableCurrent(null);

    // === === Create the Program from Shader Files

    const program: gl.uint = try ezgl.createProgramAndLinkShaders(.{
        .types = &.{ ezgl.ShaderType.vertex_shader, ezgl.ShaderType.fragment_shader },
        .paths = &.{ "src/simple_shader.vert", "src/simple_shader.frag" },
    });
    defer gl.DeleteProgram(program);

    // === === Some Global Rendering Options
    gl.Enable(gl.CULL_FACE);
    gl.CullFace(gl.BACK);

    gl.Enable(gl.DEPTH_TEST);
    gl.DepthMask(gl.TRUE);
    gl.DepthFunc(gl.LEQUAL);
    gl.DepthRange(0.0, 1.0);

    gl.Enable(gl.DEPTH_CLAMP);

    // === === Load the Gltf File into Memory
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.ioBasic();
    var arena = std.heap.ArenaAllocator.init(allocater);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var glb_data = try ezgl.readGlb("C:\\Users\\elijah\\Documents\\Blender Objects\\learn\\PBRPacked2.glb", arena_allocator, io);

    // === === Set up the Perspective Matrix
    var perspective_matrix = [_]f32{0} ** 16;
    const z_near = 1.0;
    const z_far = 45.0;
    const frustum_scale = ezgl.calcFrustumScale(45, false);
    perspective_matrix[0] = frustum_scale;
    perspective_matrix[5] = frustum_scale;
    perspective_matrix[10] = (z_far + z_near) / (z_near - z_far);
    perspective_matrix[14] = (2 * z_far * z_near) / (z_near - z_far);
    perspective_matrix[11] = -1.0;
    perspective_matrix[15] = 0.0;

    const trs_matrix: [16]f32 = ezmath.matrixIdentity();
    //ezmath.matrixTranslate(&trs_matrix, .{ 0.5, 0.5, -3.0 });
    //ezmath.matrixScale(&trs_matrix, .{ 0.25, 0.25, 0.25 });

    var camera_position: @Vector(3, f32) = .{ 0.0, 0, 3 };

    const camera_up: @Vector(3, f32) = .{ 0, 1, 0 };
    var camera_front: @Vector(3, f32) = .{ 0, 0, -1 };

    try ezgl.uploadGltf(&glb_data, allocater);

    var render_options: ezgl.RenderOptions = .{
        .program = program,
        .frustum = .{ .scale = frustum_scale, .z_near = z_near, .z_far = z_far },
        .perspective = perspective_matrix,
        .world_to_camera = ezmath.matrixIdentity(),
    };

    const move_speed_per_second = 1;
    const angle_speed_per_second = 1;

    var phi: f32 = std.math.pi;
    var theta: f32 = std.math.pi / 2.0;
    const theta_uppper = std.math.pi / 180.0 * 179.0;
    const theta_lower = std.math.pi / 180.0 * 1.0;

    var delta_time: f64 = 0.0;
    var last_frame_time: f64 = 0.0;

    var last_cursor_position: @Vector(2, f64) = .{ 0.0, 0.0 };

    const sens: f64 = 1;

    // === === Main Display Loop
    while (c.glfwWindowShouldClose(window) != gl.TRUE) {

        // get time
        const current_frame_time = c.glfwGetTime();
        delta_time = current_frame_time - last_frame_time;
        last_frame_time = current_frame_time;

        // get movement info
        const move_speed: f32 = move_speed_per_second * @as(f32, @floatCast(delta_time));
        const angle_speed: f32 = angle_speed_per_second * @as(f32, @floatCast(delta_time));

        if (move_keys[0]) camera_position += (camera_front * @as(@Vector(3, f32), @splat(move_speed))); // W
        if (move_keys[1]) camera_position -= ezmath.normalize(ezmath.cross(camera_front, camera_up)) * @as(@Vector(3, f32), @splat(move_speed)); //A
        if (move_keys[2]) camera_position -= camera_front * @as(@Vector(3, f32), @splat(move_speed)); // S
        if (move_keys[3]) camera_position += ezmath.normalize(ezmath.cross(camera_front, camera_up)) * @as(@Vector(3, f32), @splat(move_speed)); //D
        if (move_keys[4]) camera_position[1] += move_speed; // Q
        if (move_keys[5]) camera_position[1] -= move_speed; // E

        if (camera_keys[0]) { //left key
            phi += angle_speed;
        } else if (camera_keys[1]) { //right key
            phi -= angle_speed;
        } else if (camera_keys[2]) { // up key
            theta -= angle_speed;
        } else if (camera_keys[3]) { // down key
            theta += angle_speed;
        }

        var cursor_x: f64 = undefined;
        var cursor_y: f64 = undefined;
        c.glfwGetCursorPos(window, &cursor_x, &cursor_y);
        const cursor_delta = @as(@Vector(2, f64), .{ cursor_x, cursor_y }) - last_cursor_position;

        const true_sens: f64 = sens * delta_time;
        theta += @floatCast(true_sens * cursor_delta[1]);
        if (theta < theta_lower) theta = theta_lower;
        if (theta > theta_uppper) theta = theta_uppper;
        phi -= @floatCast(true_sens * cursor_delta[0]);

        last_cursor_position = .{ cursor_x, cursor_y };

        camera_front = .{ @sin(theta) * @sin(phi), @cos(theta), @sin(theta) * @cos(phi) };

        // actually render

        gl.ClearColor(0.0, 0.0, 0.0, 0.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        gl.UseProgram(program);
        defer gl.UseProgram(0);

        //ezmath.matrixTranslate(&trs_matrix, offset);
        //ezmath.matrixRotate(&trs_matrix, rot);

        render_options.world_to_camera = ezmath.lookAt(camera_position, camera_position + camera_front, camera_up);

        try ezgl.renderGltf(glb_data, trs_matrix, &render_options);

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}
