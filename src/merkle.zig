const std = @import("std");

const ConstantsFile = @embedFile("constants.json"); // must be in src/

const PoseidonConstants = struct {
    c: [90]u64,
    mds: [3][3]u64,
};

const parsed_constants = blk: {
    const parsed = std.json.parseFromSlice(PoseidonConstants, ConstantsFile,.{}) catch @compileError("Bad constants.json");
    break :blk parsed.value;
};

const C = parsed_constants.c;
const MDS = parsed_constants.mds;
pub const Leaf = [32]u8;
pub const Hash = [32]u8;

fn addMod(a: u64, b: u64) u64 { return (a +% b); }
fn mulMod(a: u64, b: u64) u64 { return (a *% b); }

fn poseidonPerm(state: *[3]u64, round: usize) void {
    for (0..3) |i| state[i] +%= C[round * 3 + i];
    // Full rounds first 4 and last 22, partial in middle
    if (round < 4 or round >= 4 + 22) {
        for (0..3) |i| state[i] = state[i] *% state[i] *% state[i] *% state[i] *% state[i]; // x^5
    }
    var new: [3]u64 =.{0,0,0};
    for (0..3) |i| {
        var sum: u64 = 0;
        for (0..3) |j| sum +%= mulMod(MDS[i][j], state[j]);
        new[i] = sum;
    }
    state.* = new;
}

fn poseidonHash(inputs: [3]u64) u64 {
    var s = inputs;
    for (0..30) |r| poseidonPerm(&s, r);
    return s[0];
}

fn hashBytes(data: Leaf) u64 {
    const a = std.mem.readInt(u64, data[0..8],.little);
    const b = std.mem.readInt(u64, data[8..16],.little);
    const c = std.mem.readInt(u64, data[16..24],.little);
    return poseidonHash(.{a ^ b, c, 0});
}

fn hashPair(left: Hash, right: Hash) Hash {
    const l = hashBytes(left);
    const r = hashBytes(right);
    const out = poseidonHash(.{l, r, 0});
    var res: Hash = undefined;
    std.mem.writeInt(u64, res[0..8], out,.little);
    return res;
}

pub const ProofStep = struct {
    sibling: Hash,
    is_left: bool, // true if current node was right child
};

pub const MerkleProof = struct {
    steps: []ProofStep,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *MerkleProof) void {
        self.allocator.free(self.steps);
    }
};

pub fn computeRoot(leaves: []const Leaf)!Hash {
    if (leaves.len == 0) return [_]u8{0} ** 32;

    const allocator = std.heap.page_allocator;
    var buf = try allocator.alloc(Hash, leaves.len);
    defer allocator.free(buf);

    for (leaves, 0..) |leaf, i| {
        buf[i] = hashBytes(leaf);
    }

    var n = leaves.len;
    while (n > 1) {
        var i: usize = 0;
        while (i < n) : (i += 2) {
            const l = buf[i];
            const r = if (i + 1 < n) buf[i + 1] else l; // duplicate last if odd
            buf[i / 2] = hashPair(l, r);
        }
        n = (n + 1) / 2;
    }
    return buf[0];
}

pub fn generateProof(allocator: std.mem.Allocator, leaves: []const Leaf, mut index: usize)!MerkleProof {
    if (leaves.len == 0) return error.EmptyTree;

    var buf = try allocator.alloc(Hash, leaves.len);
    defer allocator.free(buf);
    for (leaves, 0..) |leaf, i| buf[i] = hashBytes(leaf);

    const depth = std.math.log2_int(usize, std.math.ceilPowerOfTwo(usize, leaves.len) catch leaves.len);
    var steps = try allocator.alloc(ProofStep, depth);
    var step_idx: usize = 0;
    var n = leaves.len;

    while (n > 1) {
        const sibling_idx = if (index % 2 == 0) index + 1 else index - 1;
        const sib = if (sibling_idx < n) buf[sibling_idx] else buf[index];
        steps[step_idx] =.{.sibling = sib,.is_left = index % 2 == 1 };
        step_idx += 1;
        index /= 2;

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