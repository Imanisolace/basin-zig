const std = @import("std");
pub const Fr = @import("fr").Fr;
const basin = @import("basin");

// Domain tags prevent a leaf hash from ever colliding with an internal
const LEAF_TAG: u8 = 0x00;
const NODE_TAG: u8 = 0x01;

fn hashLeaf(leaf: []const u8, allocator: std.mem.Allocator) !Fr {
    const buf = try allocator.alloc(u8, 1 + leaf.len);
    defer allocator.free(buf);
    buf[0] = LEAF_TAG;
    @memcpy(buf[1..], leaf);

    const hash = try basin.poseidonHash(buf, allocator);
    defer allocator.free(hash);
    var arr: [32]u8 = undefined;
    @memcpy(&arr, hash[0..32]);
    return Fr.fromBytes(arr);
}

fn hashPair(a: Fr, b: Fr, allocator: std.mem.Allocator) !Fr {
    const a_bytes = a.toBytes();
    const b_bytes = b.toBytes();
    var buf: [65]u8 = undefined;
    buf[0] = NODE_TAG;
    @memcpy(buf[1..33], &a_bytes);
    @memcpy(buf[33..65], &b_bytes);

    const hash = try basin.poseidonHash(&buf, allocator);
    defer allocator.free(hash);
    var arr: [32]u8 = undefined;
    @memcpy(&arr, hash[0..32]);
    return Fr.fromBytes(arr);
}

// the leaf set — no two different leaf sets can produce the same root.
fn nextLevel(current: []const Fr, allocator: std.mem.Allocator) ![]Fr {
    const len = current.len;
    const out_len = (len + 1) / 2;
    var out = try allocator.alloc(Fr, out_len);
    var i: usize = 0;
    while (i < out_len) : (i += 1) {
        const left = current[i * 2];
        if (i * 2 + 1 < len) {
            out[i] = try hashPair(left, current[i * 2 + 1], allocator);
        } else {
            out[i] = left; // carry up, no hashing
        }
    }
    return out;
}

pub fn buildMerkleRoot(leaves: []const []const u8, allocator: std.mem.Allocator) ![]u8 {
    if (leaves.len == 0) return error.EmptyInput;

    var current_level = try allocator.alloc(Fr, leaves.len);
    for (leaves, 0..) |leaf, i| {
        current_level[i] = try hashLeaf(leaf, allocator);
    }

    while (current_level.len > 1) {
        const next = try nextLevel(current_level, allocator);
        allocator.free(current_level);
        current_level = next;
    }

    const root_bytes = current_level[0].toBytes();
    const out = try allocator.alloc(u8, 32);
    @memcpy(out, &root_bytes);
    allocator.free(current_level);
    return out;
}

// A proof step is either a real sibling to hash with (side matters),
// or `null`, meaning this level had no sibling and the node carried
pub const ProofStep = struct {
    sibling: ?[32]u8,
    is_right: bool, // true if sibling is the right-hand node
};

pub fn generateProof(leaves: []const []const u8, index: usize, allocator: std.mem.Allocator) ![]ProofStep {
    if (leaves.len == 0) return error.EmptyInput;
    if (index >= leaves.len) return error.IndexOutOfBounds;

    var current_level = try allocator.alloc(Fr, leaves.len);
    defer allocator.free(current_level);
    for (leaves, 0..) |leaf, i| {
        current_level[i] = try hashLeaf(leaf, allocator);
    }

    var proof = std.ArrayList(ProofStep).init(allocator);
    var idx = index;
    var level_len = current_level.len;

    while (level_len > 1) {
        const is_left = (idx % 2 == 0);
        const sibling_idx = if (is_left) idx + 1 else idx - 1;

        if (is_left and sibling_idx >= level_len) {
            // odd trailing node, no sibling this level
            try proof.append(.{ .sibling = null, .is_right = false });
        } else {
            try proof.append(.{
                .sibling = current_level[sibling_idx].toBytes(),
                .is_right = is_left, // sibling sits on the right if we're on the left
            });
        }

        const next = try nextLevel(current_level, allocator);
        allocator.free(current_level);
        current_level = next;
        level_len = next.len;
        idx = idx / 2;
    }

    return try proof.toOwnedSlice();
}

pub fn verifyProof(
    leaf: []const u8,
    proof: []const ProofStep,
    root: [32]u8,
    allocator: std.mem.Allocator,
) !bool {
    var node = try hashLeaf(leaf, allocator);

    for (proof) |step| {
        if (step.sibling) |sib_bytes| {
            const sibling = Fr.fromBytes(sib_bytes);
            node = if (step.is_right)
                try hashPair(node, sibling, allocator)
            else
                try hashPair(sibling, node, allocator);
        }
        // null sibling: node carries up unchanged, matching buildMerkleRoot
    }

    return std.mem.eql(u8, &node.toBytes(), &root);
}