const std = @import("std");
pub const Fr = @import("fr.zig").Fr;
const basin = @import("basin");

// Hash 2 Fr elements: poseidon( left || right ) mod P
fn hashPair(a: Fr, b: Fr, allocator: std.mem.Allocator)!Fr {
    const a_bytes = a.toBytes();
    const b_bytes = b.toBytes();

    var buf: [64]u8 = undefined;
    @memcpy(buf[0..32], &a_bytes);
    @memcpy(buf[32..64], &b_bytes);

    const hash = try basin.poseidonHash(&buf, allocator);
    defer allocator.free(hash);

    var arr: [32]u8 = undefined;
    @memcpy(&arr, hash[0..32]);
    return Fr.fromBytes(arr);
}

pub fn buildMerkleRoot(leaves: []const []const u8, allocator: std.mem.Allocator)![]u8 {
    if (leaves.len == 0) return error.EmptyInput;

    // 1. Hash leaves to Fr
    var current_level = try allocator.alloc(Fr, leaves.len);

    for (leaves, 0..) |leaf, i| {
        const h = try basin.poseidonHash(leaf, allocator);
        defer allocator.free(h);
        var arr: [32]u8 = undefined;
        @memcpy(&arr, h[0..32]);
        current_level[i] = Fr.fromBytes(arr);
    }

    // 2. Build tree up. No defers in loop to avoid double free
    var level_len = current_level.len;
    while (level_len > 1) {
        const next_len = (level_len + 1) / 2;
        var next_level = try allocator.alloc(Fr, next_len);

        for (0..next_len) |i| {
            const left = current_level[i * 2];
            const right = if (i * 2 + 1 < level_len) current_level[i * 2 + 1] else left; // duplicate if odd
            next_level[i] = try hashPair(left, right, allocator);
        }
        allocator.free(current_level); // free old level
        current_level = next_level;
        level_len = next_len;
    }

    // 3. Return root as bytes
    const root_bytes = current_level[0].toBytes();
    const out = try allocator.alloc(u8, 32);
    @memcpy(out, &root_bytes);
    allocator.free(current_level); // free final level
    return out;
}