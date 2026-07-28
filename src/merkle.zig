const std = @import("std");
const consts = @import("poseidon_consts.zig");
const Fr = @import("fr.zig").Fr; // <- import your Fr

pub const Leaf = [32]u8;
pub const Hash = [32]u8;

const T = consts.T; // 3
const ROUNDS = consts.ROUNDS; // 64
const C = consts.C;
const P = consts.P;

fn sbox(x: Fr) Fr {
    const x2 = x.mul(x);
    const x4 = x2.mul(x2);
    return x4.mul(x); // x^5
}

fn matmul(s: [T]Fr) [T]Fr {
    var out: [T]Fr = undefined;
    for (0..T) |i| {
        out[i] = Fr.zero;
        for (0..T) |j| out[i] = out[i].add(P[i][j].mul(s[j]));
    }
    return out;
}

fn poseidonPerm(state_in: [T]Fr) [T]Fr {
    var state = state_in;
    var round: usize = 0;
    const RF = consts.RF; const RP = consts.RP;

    while (round < RF / 2) : (round += 1) {
        for (0..T) |i| state[i] = state[i].add(C[round*T + i]);
        for (0..T) |i| state[i] = sbox(state[i]);
        state = matmul(state);
    }
    while (round < RF / 2 + RP) : (round += 1) {
        for (0..T) |i| state[i] = state[i].add(C[round*T + i]);
        state[0] = sbox(state[0]);
        state = matmul(state);
    }
    while (round < ROUNDS) : (round += 1) {
        for (0..T) |i| state[i] = state[i].add(C[round*T + i]);
        for (0..T) |i| state[i] = sbox(state[i]);
        state = matmul(state);
    }
    return state;
}

fn poseidonHash(inputs: [T]Fr) Fr {
    return poseidonPerm(inputs)[0];
}

fn frFromBytes(b: [32]u8) Fr {
    return Fr.fromBytes(b);
}

fn frToBytes(x: Fr) [32]u8 {
    return x.toBytes(); // or whatever your Fr has
}

fn hashLeaf(data: Leaf) Hash {
    var a_bytes: [32]u8 = [_]u8{0} ** 32; @memcpy(a_bytes[0..8], data[0..8]);
    var b_bytes: [32]u8 = [_]u8{0} ** 32; @memcpy(b_bytes[0..8], data[8..16]);
    var c_bytes: [32]u8 = [_]u8{0} ** 32; @memcpy(c_bytes[0..8], data[16..24]);

    const a = frFromBytes(a_bytes);
    const b = frFromBytes(b_bytes);
    const c = frFromBytes(c_bytes);

    return frToBytes(poseidonHash(.{a.add(b), c, Fr.zero}));
}

fn hashPair(l: Hash, r: Hash) Hash {
    return frToBytes(poseidonHash(.{frFromBytes(l), frFromBytes(r), Fr.zero}));
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