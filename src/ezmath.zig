const std = @import("std");

// === === === === === === === Matrix Math Module === === === === === === ===

/// A column-major matrix Library
pub const Mat4x4 = struct {
    mat: [4][4]f32,

    pub fn identity() Mat4x4 {
        var ret: Mat4x4 = undefined;
        for (0..4) |i| {
            for (0..4) |j| {
                ret.mat[i][j] = if (i == j) 1 else 0;
            }
        }
        return ret;
    }

    pub fn rotateZ(self: *Mat4x4, theta: f32) Mat4x4 {
        // zig fmt: off
        const rot_mat = [4][4]f32{
            .{@cos(theta), -@sin(theta), 0.0, 0.0},
            .{@sin(theta), @cos(theta), 0.0, 0.0},
            .{0.0, 0.0, 1.0, 0.0},
            .{0.0, 0.0, 0.0, 0.0},
        };
        // zig fmt: on
        return Mat4x4.multiply(self.mat, rot_mat);
    }

    pub fn multiply(a: [4][4]f32, b: [4][4]f32) Mat4x4 {
        var ret: Mat4x4 = undefined;
        for (0..4) |i| {
            for (0..4) |j| {
                ret.mat[i][j] = dot(a[i], .{ b[0][j], b[1][j], b[2][j], b[3][j] });
            }
        }
        return ret;
    }

    pub fn translate(self: *Mat4x4, translation: @Vector(3, f32)) void {
        self.mat[3][0] += translation[0];
        self.mat[3][1] += translation[1];
        self.mat[3][2] += translation[2];
    }

    pub fn toBuffer(self: *Mat4x4, transpose: bool) [16]f32 {
        var ret: [16]f32 = undefined;
        for (0..4) |i| {
            for (0..4) |j| {
                if (transpose) {
                    ret[i + j * 4] = self.mat[i][j];
                } else {
                    ret[i + j * 4] = self.mat[j][i];
                }
            }
        }
        return ret;
    }
};

/// This does a * b in that order and stores in a
/// A and B are column major
pub fn matrixMultiply(a: *[16]f32, b: [16]f32) void {
    var ret: [16]f32 = undefined;
    for (0..4) |col| {
        for (0..4) |row| {
            ret[col + row * 4] = dot(.{ a.*[col], a.*[col + 4], a.*[col + 8], a.*[col + 12] }, .{ b[row * 4], b[row * 4 + 1], b[row * 4 + 2], b[row * 4 + 3] });
        }
    }
    a.* = ret;
}

pub fn matrixMultiplyNew(a: [16]f32, b: [16]f32) [16]f32 {
    var copy = matrixCopy(a);
    matrixMultiply(&copy, b);
    return copy;
}

pub fn matrixScale(a: *[16]f32, scale: @Vector(3, f32)) void {
    const scale_mat: [16]f32 = .{ scale[0], 0.0, 0.0, 0.0, 0.0, scale[1], 0.0, 0.0, 0.0, 0.0, scale[2], 0.0, 0.0, 0.0, 0.0, 1.0 };
    matrixMultiply(a, scale_mat);
}

pub fn matrixTranslate(a: *[16]f32, offset: @Vector(3, f32)) void {
    const translate_mat: [16]f32 = .{ 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, offset[0], offset[1], offset[2], 1.0 };
    matrixMultiply(a, translate_mat);
}

pub fn matrixRotate(a: *[16]f32, rotation: @Vector(4, f32)) void {
    matrixMultiply(a, quatToRotationMatrix(rotation));
}

pub fn matrixIdentity() [16]f32 {
    return .{ 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0 };
}

pub fn matrixTranspose(a: *[16]f32) void {
    var tmp: f32 = undefined;
    for (1..4) |i| {
        for (0..i) |j| {
            tmp = a.*[j + 4 * i];
            a.*[j + 4 * i] = a.*[i + 4 * j];
            a.*[i + 4 * j] = tmp;
        }
    }
}

pub fn quatToRotationMatrix(rotation: [4]f32) [16]f32 {
    const qi = rotation[0];
    const qj = rotation[1];
    const qk = rotation[2];
    const qr = rotation[3];
    // zig fmt: off
    const rotation_mat: [16]f32 = .{
        1 - (2 * (qj * qj + qk * qk)),
        2 * (qi * qj + qk * qr),
        2 * (qi * qk - qj * qr),
        0.0,

        2 * (qi * qj - qk * qr),
        1 - (2 * (qi * qi + qk * qk)),
        2 * (qj * qk + qi * qr),
        0.0,

        2 * (qi * qk + qj * qr),
        2 * (qj * qk - qi * qr),
        1 - (2 * (qi * qi + qj * qj)),
        0.0,

        0.0,
        0.0,
        0.0,
        1.0,
    };

    return rotation_mat;
}

pub fn offsetToTranslationMatrix(offset: [3]f32) [16]f32 {
    return .{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, offset[0], offset[1], offset[2], 1};
}

pub fn matrixCopy(a: [16]f32) [16]f32 {
    var ret: [16]f32 = undefined;
    for (0..16) |i| {
        ret[i] = a[i];
    }
    return ret;
}

pub fn dot(a: @Vector(4, f32), b: @Vector(4, f32)) f32 {
    return @reduce(.Add, a * b);
}

pub fn cross(a: @Vector(3, f32), b: @Vector(3, f32)) @Vector(3, f32) {
    return .{a[1]*b[2] - a[2]*b[1], a[2]*b[0] - a[0]*b[2], a[0]*b[1]-a[1]*b[0]};
}

pub fn normalize(a: @Vector(3, f32)) @Vector(3, f32) {
    const divisor: @Vector(3, f32) = @splat(@sqrt(@reduce(.Add, a * a)));
    return a / divisor;
}

pub fn quatMultiply(a: [4]f32, b: [4]f32) [4]f32 {
    var ret: [4]f32 = [_]f32{ 0, 0, 0, 0 };
    ret[3] = a[3] * b[3] - a[0] * b[0] - a[1] * b[1] - a[2] * b[2];
    ret[0] = a[3] * b[0] + a[0] * b[3] + a[1] * b[2] - a[2] * b[1];
    ret[1] = a[3] * b[1] + a[1] * b[3] - a[0] * b[2] + a[2] * b[0];
    ret[2] = a[3] * b[2] + a[2] * b[3] + a[0] * b[1] - a[1] * b[0];
    return ret;
}

pub fn quatInverse(a: [4]f32) [4]f32 {
    return .{-a[0], -a[1], -a[2], a[3]};
}

pub fn vectorQuatRotate(q: [4]f32, p: [3]f32) [3]f32 {
    const res = quatMultiply(quatMultiply(q, .{p[0], p[1], p[2], 0}), quatInverse(q))[0..3];
    return .{res[0], res[1], res[2]};
}

/// Get det of upper left 3x3 in 4x4 mat
pub fn det(a: [16]f32) f32 {
    return (a[0] * (a[5] * a[10] - a[6] * a[9])) - (a[4] * (a[1] * a[10] - a[2] * a[9])) + (a[8] * (a[1] * a[6] - a[2] * a[5]));
}

pub fn lookAt(position: @Vector(3, f32), target: @Vector(3, f32), up: @Vector(3, f32)) [16]f32 {
    const reverse_direction: @Vector(3, f32) = normalize(position - target);
    const local_right = normalize(cross(up, reverse_direction));
    const local_up = cross(reverse_direction, local_right);

    const rotation_matrix = .{local_right[0], local_up[0], reverse_direction[0], 0, local_right[1], local_up[1], reverse_direction[1], 0,local_right[2], local_up[2], reverse_direction[2], 0, 0, 0, 0, 1,};
    const neg: @Vector(3, f32) = @splat(-1);
    return matrixMultiplyNew(rotation_matrix, offsetToTranslationMatrix(neg * position));
}


test "test dot product" {
    const a: [4]f32 = .{ 1, 2, 3, 4 };
    const b: [4]f32 = .{ 5, 6, 7, 8 };

    try std.testing.expect(dot(a, b) == 70);
}

test "test matrix multiply" {
    // zig fmt: off
    const a: [4][4]f32 = .{
        .{1.0, 6.0, 0.0, 3.0},
        .{0.0, 0.0, 1.0, 0.0},
        .{5.0, 5.0, 0.0, 9.0},
        .{0.0, 7.0, 0.0, 0.0},
    };

    const b: [4][4]f32 = .{
        .{5.0, 0.0, 1.0, 0.0},
        .{0.0, 4.0, 6.0, 0.0},
        .{0.0, 9.0, 0.0, 2.0},
        .{8.0, 0.0, 5.0, 0.0},
    };

    const expected: [4][4]f32 = .{
        .{29.0, 24.0, 52.0, 0.0},
        .{0.0, 9.0, 0.0, 2.0},
        .{97.0, 20.0, 80.0, 0.0},
        .{0.0, 28.0, 42.0, 0.0},
    };
    // zig fmt: on

    try std.testing.expectEqualDeep(expected, Mat4x4.multiply(a, b).mat);
}

test "text buffer matrix multiply" {
    var a: [16]f32 = .{ 1.0, 0.0, 5.0, 0.0, 6.0, 0.0, 5.0, 7.0, 0.0, 1.0, 0.0, 0.0, 3.0, 0.0, 9.0, 0.0 };
    const b: [16]f32 = .{ 5.0, 0.0, 0.0, 8.0, 0.0, 4.0, 9.0, 0.0, 1.0, 6.0, 0.0, 5.0, 0.0, 0.0, 2.0, 0.0 };
    const expected: [16]f32 = .{ 29.0, 0.0, 97.0, 0.0, 24.0, 9.0, 20.0, 28.0, 52.0, 0.0, 80.0, 42.0, 0.0, 2.0, 0.0, 0.0 };
    matrixMultiply(&a, b);
    try std.testing.expectEqualDeep(expected, a);
}

test "text buffer upper right determinant" {
    const a: [16]f32 = .{ 1, 2, 1, 27328, 3, 23, 5, 32131, 2, 4, 3, 3121, 69, 25198, 312, 3214 };
    try std.testing.expect(det(a) == 17);
}

test "quaternion multiply" {
    const a = [_]f32{ 2, 3, 2, 5 };
    const b = [_]f32{ 1, 8, 2, 1 };
    const expect = [_]f32{ -3, 41, 25, -25 };
    try std.testing.expectEqualDeep(quatMultiply(a, b), expect);
}

test "test matrix transpose" {
    var a: [16]f32 = .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
    const expected: [16]f32 = .{ 0, 4, 8, 12, 1, 5, 9, 13, 2, 6, 10, 14, 3, 7, 11, 15 };
    matrixTranspose(&a);
    try std.testing.expectEqualDeep(a, expected);
}

test "cross product" {
    try std.testing.expectEqualDeep(cross(.{ 3, 0, 2 }, .{ -1, 4, 2 }), .{ -8, -8, 12 });
}

test "normalize" {
    try std.testing.expectEqualDeep(normalize(.{ 2, 3, 6 }), .{ 2.0 / 7.0, 3.0 / 7.0, 6.0 / 7.0 });
}
