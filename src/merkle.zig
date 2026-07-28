const std = @import("std");
const consts = @import("poseidon_consts.zig");

pub const Leaf = [32]u8;
pub const Hash = [32]u8;

const T = 3;
const RF = 8;
const RP = 56;
const ROUNDS = RF + RP;
const C = consts.C;
const P = consts.P;

fn pow5(x: u64) u64 { return x *% x *% x *% x *% x; }

fn applyP(state: *[T]u64) void {
    var new: [T]u64 =.{0} ** T;
    for (0..T) |i| for (0..T) |j| new[i] +%= P[i][j] *% state[j];
    state.* = new;
}

fn poseidonPerm(state: *[T]u64, round: usize) void {
    for (0..T) |i| state[i] +%= C[round * T + i];
    if (round < RF/2 or round >= RF/2 + RP) {
        for (0..T) |i| state[i] = pow5(state[i]);
    } else {
        state[0] = pow5(state[0]);
    }
    applyP(state);
}

fn poseidonHash(inputs: [T]u64) u64 {
    var s = inputs;
    for (0..ROUNDS) |r| poseidonPerm(&s, r);
    return s[0];
}

fn toHash(x: u64) Hash {
    var res: Hash = [_]u8{0} ** 32;
    std.mem.writeInt(u64, res[0..8], x,.little);
    return res;
}

fn hashLeaf(data: Leaf) Hash {
    const a = std.mem.readInt(u64, data[0..8],.little);
    const b = std.mem.readInt(u64, data[8..16],.little);
    const c = std.mem.readInt(u64, data[16..24],.little);
    return toHash(poseidonHash(.{a ^ b, c, 0}));
}

fn hashPair(l: Hash, r: Hash) Hash {
    const a = std.mem.readInt(u64, l[0..8],.little);
    const b = std.mem.readInt(u64, r[0..8],.little);
    return toHash(poseidonHash(.{a, b, 0}));
}

pub const ProofStep = struct { sibling: Hash, is_left: bool };
pub const MerkleProof = struct {
    steps: []ProofStep, allocator: std.mem.Allocator,
    pub fn deinit(self: *MerkleProof) void { self.allocator.free(self.steps); }
};

pub fn computeRoot(allocator: std.mem.Allocator, leaves: []const Leaf)!Hash {
    if (leaves.len == 0) return [_]u8{0} ** 32;
    var buf = try allocator.alloc(Hash, leaves.len); defer allocator.free(buf);
    for (leaves, 0..) |leaf, i| buf[i] = hashLeaf(leaf);
    var n = leaves.len;
    while (n > 1) {
        var i: usize = 0; while (i < n) : (i += 2) {
            const l = buf[i]; const r = if (i + 1 < n) buf[i + 1] else l;
            buf[i / 2] = hashPair(l, r);
        }
        n = (n + 1) / 2;
    }
    return buf[0];
}

pub fn generateProof(allocator: std.mem.Allocator, leaves: []const Leaf, index: usize)!MerkleProof {
    var idx = index; var buf = try allocator.alloc(Hash, leaves.len); defer allocator.free(buf);
    for (leaves, 0..) |leaf, i| buf[i] = hashLeaf(leaf);
    const depth = std.math.log2_int(usize, std.math.ceilPowerOfTwo(usize, leaves.len) catch leaves.len);
    var steps = try allocator.alloc(ProofStep, depth); var step_idx: usize = 0; var n = leaves.len;
    while (n > 1) {
        const sib_idx = if (idx % 2 == 0) idx + 1 else idx - 1;
        const sib = if (sib_idx < n) buf[sib_idx] else buf[idx];
        steps[step_idx] =.{.sibling = sib,.is_left = idx % 2 == 1 }; step_idx += 1; idx /= 2;
        var i: usize = 0; while (i < n) : (i += 2) {
            const l = buf[i]; const r = if (i + 1 < n) buf[i + 1] else l;
            buf[i / 2] = hashPair(l, r);
        }
        n = (n + 1) / 2;
    }
    return MerkleProof{.steps = steps[0..step_idx],.allocator = allocator };
}

pub fn verifyProof(leaf: Leaf, proof: MerkleProof, root: Hash) bool {
    var cur = hashLeaf(leaf);
    for (proof.steps) |step| {
        cur = if (step.is_left) hashPair(step.sibling, cur) else hashPair(cur, step.sibling);
    }
    return std.mem.eql(u8, &cur, &root);
}