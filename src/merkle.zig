const std = @import("std");

const ConstantsFile = @embedFile("constants.json");

const PoseidonConstants = struct {
    c: [90]u64,
    mds: [3][3]u64,
};

// Parse at comptime without allocator
const parsed_constants = comptime blk: {
    const parsed = std.json.parseFromSliceLeaky(PoseidonConstants, std.heap.page_allocator, ConstantsFile) catch
        @compileError("Bad constants.json");
    break :blk parsed;
};

const C = parsed_constants.c;
const MDS = parsed_constants.mds;
pub const Leaf = [32]u8;
pub const Hash = [32]u8;

fn poseidonPerm(state: *[3]u64, round: usize) void {
    for (0..3) |i| state[i] +%= C[round * 3 + i];
    if (round < 4 or round >= 4 + 22) {
        for (0..3) |i| state[i] = state[i] *% state[i] *% state[i] *% state[i] *% state[i];
    }
    var new: [3]u64 =.{0,0,0};
    for (0..3) |i| {
        var sum: u64 = 0;
        for (0..3) |j| sum +%= MDS[i][j] *% state[j];
        new[i] = sum;
    }
    state.* = new;
}

fn poseidonHash(inputs: [3]u64) u64 {
    var s = inputs;
    for (0..30) |r| poseidonPerm(&s, r);
    return s[0];
}

fn hashToBytes(x: u64) Hash {
    var res: Hash = [_]u8{0} ** 32;
    std.mem.writeInt(u64, res[0..8], x,.little);
    return res;
}

fn hashBytes(data: Leaf) Hash {
    const a = std.mem.readInt(u64, data[0..8],.little);
    const b = std.mem.readInt(u64, data[8..16],.little);
    const c = std.mem.readInt(u64, data[16..24],.little);
    const out = poseidonHash(.{a ^ b, c, 0});
    return hashToBytes(out);
}

fn hashPair(left: Hash, right: Hash) Hash {
    const l = std.mem.readInt(u64, hashBytes(left)[0..8],.little);
    const r = std.mem.readInt(u64, hashBytes(right)[0..8],.little);
    const out = poseidonHash(.{l, r, 0});
    return hashToBytes(out);
}

pub const ProofStep = struct {
    sibling: Hash,
    is_left: bool,
};

pub const MerkleProof = struct {
    steps: []ProofStep,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *MerkleProof) void {
        self.allocator.free(self.steps);
    }
};

pub fn computeRoot(allocator: std.mem.Allocator, leaves: []const Leaf)!Hash {
    if (leaves.len == 0) return [_]u8{0} ** 32;
    var buf = try allocator.alloc(Hash, leaves.len);
    defer allocator.free(buf);

    for (leaves, 0..) |leaf, i| buf[i] = hashBytes(leaf);

    var n = leaves.len;
    while (n > 1) {
        var i: usize = 0;
        while (i < n) : (i += 2) {
            const l = buf[i];
            const r = if (i + 1 < n) buf[i + 1] else l;
            buf[i / 2] = hashPair(l, r);
        }
        n = (n + 1) / 2;
    }
    return buf[0];
}

pub fn generateProof(allocator: std.mem.Allocator, leaves: []const Leaf, index: usize)!MerkleProof {
    if (leaves.len == 0) return error.EmptyTree;
    var idx = index;

    var buf = try allocator.alloc(Hash, leaves.len);
    defer allocator.free(buf);
    for (leaves, 0..) |leaf, i| buf[i] = hashBytes(leaf);

    const depth = std.math.log2_int(usize, std.math.ceilPowerOfTwo(usize, leaves.len) catch leaves.len);
    var steps = try allocator.alloc(ProofStep, depth);
    var step_idx: usize = 0;
    var n = leaves.len;

    while (n > 1) {
        const sibling_idx = if (idx % 2 == 0) idx + 1 else idx - 1;
        const sib = if (sibling_idx < n) buf[sibling_idx] else buf[idx];
        steps[step_idx] =.{.sibling = sib,.is_left = idx % 2 == 1 };
        step_idx += 1;
        idx /= 2;

        var i: usize = 0;
        while (i < n) : (i += 2) {
            const l = buf[i];
            const r = if (i + 1 < n) buf[i + 1] else l;
            buf[i / 2] = hashPair(l, r);
        }
        n = (n + 1) / 2;
    }
    return MerkleProof{.steps = steps[0..step_idx],.allocator = allocator };
}

pub fn verifyProof(leaf: Leaf, proof: MerkleProof, root: Hash) bool {
    var cur = hashBytes(leaf);
    for (proof.steps) |step| {
        cur = if (step.is_left) hashPair(step.sibling, cur) else hashPair(cur, step.sibling);
    }
    return std.mem.eql(u8, &cur, &root);
}