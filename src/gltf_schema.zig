const std = @import("std");
const ezgl = @import("ezgl");
const JsonValue = std.json.Value;

pub const Accessor = struct {
    bufferView: ?GltfId = null,
    byteOffset: u64 = 0, // >= 0
    componentType: i64,
    normalized: bool = false,
    count: u64, // >= 1
    type: []const u8,
    max: ?[]const f64 = null, // 1 <= len <= 16
    min: ?[]const f64 = null, // 1 <= len <= 16
    sparse: ?AccessorSparse = null,
    name: ?[]const u8 = null,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const AccessorSparse = struct {
    count: u64, //>=1
    indices: AccessorSparseIndices,
    values: AccessorSparseValues,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const AccessorSparseIndices = struct {
    bufferView: GltfId,
    byteOffset: u64 = 0,
    componentType: i64,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const AccessorSparseValues = struct {
    bufferView: GltfId,
    byteOffset: u64 = 0,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const Animation = struct {
    channels: []const AnimationChannel,
    samplers: []const AnimationSampler,
    name: ?[]const u8 = null,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const AnimationChannel = struct {
    sampler: GltfId,
    target: AnimationChannelTarget,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const AnimationChannelTarget = struct {
    node: ?GltfId = null,
    path: []const u8,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const AnimationSampler = struct {
    input: GltfId,
    interpolation: ?[]const u8 = null,
    output: GltfId,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const Asset = struct {
    copyright: ?[]const u8 = null,
    generator: ?[]const u8 = null,
    version: []const u8,
    minVersion: ?[]const u8 = null,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const Buffer = struct {
    uri: ?[]const u8 = null,
    byteLength: u64, // >= 1
    name: ?[]const u8 = null,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const BufferView = struct {
    buffer: GltfId,
    byteOffset: u64 = 0,
    byteLength: u64,
    byteStride: ?u64 = null,
    target: ?i64 = null,
    name: ?[]const u8 = null,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const Camera = struct {
    orthographic: ?CameraOrthographic = null,
    perspective: ?CameraPerspective = null,
    type: []const u8,
    name: ?[]const u8 = null,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const CameraOrthographic = struct {
    xmag: f64,
    ymag: f64,
    zfar: f64,
    znear: f64,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const CameraPerspective = struct {
    aspectRatio: ?f64 = null,
    yfov: f64,
    zfar: ?f64 = null,
    znear: f64,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const Extension = ?JsonValue;

pub const Extras = ?JsonValue;

pub const Gltf = struct {
    extensionsUsed: ?[]const []const u8 = null,
    extensionsRequired: ?[]const []const u8 = null,
    accessors: ?[]const Accessor = null,
    animations: ?[]const Animation = null,
    asset: Asset,
    buffers: ?[]const Buffer = null,
    bufferViews: ?[]const BufferView = null,
    cameras: ?[]const Camera = null,
    images: ?[]const Image = null,
    materials: ?[]const Material = null,
    meshes: ?[]Mesh = null,
    nodes: ?[]const Node = null,
    samplers: ?[]const Sampler = null,
    scene: ?GltfId = null,
    scenes: ?[]const Scene = null,
    skins: ?[]const Skin = null,
    textures: ?[]Texture = null,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const GltfChildOfRootProperty = struct {
    name: ?[]const u8 = null,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const GltfId = u32;

pub const GltfProperty = struct {
    extensions: Extension = null,
    extras: Extras = null,
};

pub const Image = struct {
    uri: ?[]const u8 = null,
    mimeType: ?[]const u8 = null,
    bufferView: ?GltfId = null,
    name: ?[]const u8 = null,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const Material = struct {
    pbrMetallicRoughness: MaterialPbrMetallicRoughness = .{},
    normalTexture: ?MaterialNormalTextureInfo = null,
    occlusionTexture: ?MaterialOcclusionTextureInfo = null,
    emissiveTexture: ?TextureInfo = null,
    emissiveFactor: [3]f64 = [_]f64{ 0.0, 0.0, 0.0 },
    alphaMode: []const u8 = "OPAQUE",
    alphaCutoff: f64 = 0.5,
    doubleSided: bool = false,
    name: ?[]const u8 = null,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const MaterialNormalTextureInfo = struct {
    index: ?GltfId = null,
    texCoord: u64 = 0, //>= 0
    scale: f64 = 1.0,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const MaterialOcclusionTextureInfo = struct {
    index: ?GltfId = null,
    texCoord: u64 = 0, //>= 0
    strength: f64 = 1.0,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const MaterialPbrMetallicRoughness = struct {
    baseColorFactor: [4]f32 = [_]f32{ 1.0, 1.0, 1.0, 1.0 },
    baseColorTexture: ?TextureInfo = null,
    metallicFactor: f64 = 1.0,
    roughnessFactor: f64 = 1.0,
    metallicRoughnessTexture: ?TextureInfo = null,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const Mesh = struct {
    primitives: []MeshPrimitive,
    weights: ?[]const f64 = null,
    name: ?[]const u8 = null,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const MeshPrimitive = struct {
    attributes: std.json.ArrayHashMap(GltfId),
    indices: ?GltfId = null,
    material: ?GltfId = null,
    mode: i64 = 4,
    targets: ?[]const std.json.ArrayHashMap(GltfId) = null,
    extensions: Extension = null,
    extras: ?MeshPrimitiveExtras = null,
};

pub const MeshPrimitiveExtras = struct {
    uploadedPrimitive: ?ezgl.UploadedMeshPrimitive = null,
};

pub const Node = struct {
    camera: ?GltfId = null,
    children: ?[]const GltfId = null,
    skin: ?GltfId = null,
    matrix: ?[16]f32 = null, //[_]f64{ 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0 },
    mesh: ?GltfId = null,
    rotation: ?[4]f32 = null, //[_]f64{ 0.0, 0.0, 0.0, 1.0 },
    scale: ?[3]f32 = null, //[_]f64{ 1.0, 1.0, 1.0 },
    translation: ?[3]f32 = null, //[_]f64{ 0.0, 0.0, 0.0 },
    weights: ?[]const f32 = null,
    name: ?[]const u8 = null,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const Sampler = struct {
    magFilter: ?i64 = null,
    minFilter: ?i64 = null,
    wrapS: i64 = 10497,
    wrapT: i64 = 10497,
    name: ?[]const u8 = null,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const Scene = struct {
    nodes: ?[]const GltfId = null,
    name: ?[]const u8 = null,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const Skin = struct {
    inverseBindMatrices: ?GltfId = null,
    skeleton: ?GltfId = null,
    joints: []const GltfId,
    name: ?[]const u8 = null,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const Texture = struct {
    sampler: ?GltfId = null,
    source: ?GltfId = null,
    name: ?[]const u8 = null,
    extensions: ?TextureExtension = null,
    extras: ?TextureExtras = null,
};

pub const TextureExtension = struct {
    KHR_texture_basisu: ?KhrTextureBasisu = null,
};

pub const TextureExtras = struct {
    uploadedTexture: ?ezgl.UploadedTexture = null,
};

pub const KhrTextureBasisu = struct {
    source: u32,
};

pub const KhrTextureTransform = struct {
    offset: [2]f32 = [2]f32{ 0, 0 },
    rotation: f32 = 0.0,
    scale: [2]f32 = [2]f32{ 1, 1 },
    texCoord: ?i32 = null,
    extensions: Extension = null,
    extras: Extras = null,
};

pub const TextureInfo = struct {
    index: GltfId,
    texCoord: u64 = 0, //>= 0
    extensions: ?TextureInfoExtension = null,
    extras: Extras = null,
};

pub const TextureInfoExtension = struct {
    KHR_texture_transform: ?KhrTextureTransform = null,
};
