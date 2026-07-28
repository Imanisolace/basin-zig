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
    var current_level = try allocator.alloc(Fr, leaves.len);
    for (leaves, 0..) |leaf, i| {
        const h = try basin.poseidonHash(leaf, allocator);
        defer allocator.free(h);
        var arr: [32]u8 = undefined;
        @memcpy(&arr, h[0..32]);
        current_level[i] = Fr.fromBytes(arr);
    }
    var level_len = current_level.len;
    while (level_len > 1) {
        const next_len = (level_len + 1) / 2;
        var next_level = try allocator.alloc(Fr, next_len);
        for (0..next_len) |i| {
            const left = current_level[i * 2];
            const right = if (i * 2 + 1 < level_len) current_level[i * 2 + 1] else left;
            next_level[i] = try hashPair(left, right, allocator);
        }
        allocator.free(current_level);
        current_level = next_level;
        level_len = next_len;
    }
    const root_bytes = current_level[0].toBytes();
    const out = try allocator.alloc(u8, 32);
    @memcpy(out, &root_bytes);
    allocator.free(current_level);
    return out;
}

// NEW: Generate merkle proof path for 1 leaf
pub fn generateProof(leaves: []const []const u8, index: usize, allocator: std.mem.Allocator)![][]u8 {
    if (index >= leaves.len) return error.IndexOutOfBounds;
    var current_level = try allocator.alloc(Fr, leaves.len);
    defer allocator.free(current_level);

    for (leaves, 0..) |leaf, i| {
        const h = try basin.poseidonHash(leaf, allocator);
        defer allocator.free(h);
        var arr: [32]u8 = undefined;
        @memcpy(&arr, h[0..32]);
        current_level[i] = Fr.fromBytes(arr);
    }

    var proof = std.ArrayList([]u8).init(allocator);
    var idx = index;
    var level_len = current_level.len;

    while (level_len > 1) {
        const sibling_idx = if (idx % 2 == 0) idx + 1 else idx - 1;
        const sibling = if (sibling_idx < level_len) current_level[sibling_idx] else current_level[idx];
        const sibling_bytes = try allocator.alloc(u8, 32);
        @memcpy(sibling_bytes, &sibling.toBytes());
        try proof.append(sibling_bytes);

        const next_len = (level_len + 1) / 2;
        var next_level = try allocator.alloc(Fr, next_len);
        for (0..next_len) |i| {
            const left = current_level[i * 2];
            const right = if (i * 2 + 1 < level_len) current_level[i * 2 + 1] else left;
            next_level[i] = try hashPair(left, right, allocator);
        }
        if (level_len != leaves.len) allocator.free(current_level);
        current_level = next_level;
        level_len = next_len;
        idx = idx / 2;
    }
    if (level_len != leaves.len) allocator.free(current_level);
    return try proof.toOwnedSlice();
}