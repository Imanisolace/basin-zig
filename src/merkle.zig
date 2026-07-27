const std = @import("std");
const json = std.json;

pub const OUTPUT_SIZE = 32;
pub const FIELD_MODULUS: u64 = 0xFFFFFFFF00001; // Goldilocks p = 2^64 - 2^32 + 1

pub const MerkleError = error{
    EmptyTree,
    LeafNotFound,
    InvalidProofLength,
};

pub const ProofStep = struct {
    is_right: bool,
    sibling: [OUTPUT_SIZE]u8,
};

pub const MAX_DEPTH = 32;

pub const Proof = struct {
    steps: [MAX_DEPTH]ProofStep,
    len: usize,
};

// ============ LOAD REAL CONSTANTS FROM ROOT ============
const ConstantsFile = @embedFile("../constants.json"); // <-- key change: go up 1 folder

const PoseidonConstants = struct {
    c: []u64,
    mds: [][3]u64,
};

const parsed_constants = comptime blk: {
    const parsed = json.parseFromSlice(PoseidonConstants, std.heap.page_allocator, ConstantsFile,.{}) catch @compileError("Failed to parse constants.json");
    break :blk parsed.value;
};

const ROUND_CONSTANTS = parsed_constants.c;
const MDS_MATRIX = parsed_constants.mds;
const WIDTH = 3;
const FULL_ROUNDS = 8;
const PARTIAL_ROUNDS = 22;

// ============ FIELD MATH ============
fn fieldAdd(a: u64, b: u64) u64 {
    const sum = @as(u128, a) + @as(u128, b);
    return @intCast(sum % FIELD_MODULUS);
}

fn fieldMul(a: u64, b: u64) u64 {
    const prod = @as(u128, a) * @as(u128, b);
    return @intCast(prod % FIELD_MODULUS);
}

fn fieldPow5(x: u64) u64 {
    const x2 = fieldMul(x, x);
    const x4 = fieldMul(x2, x2);
    return fieldMul(x4, x);
}

fn bytesToField(bytes: *const [OUTPUT_SIZE]u8) u64 {
    var out: u64 = 0;
    for (0..8) |i| out = (out << 8) | bytes[i];
    return out % FIELD_MODULUS;
}

fn fieldToBytes(val: u64, out: *[OUTPUT_SIZE]u8) void {
    @memset(out, 0);
    var tmp = val;
    var i: usize = 8;
    while (i > 0) {
        i -= 1;
        out[i] = @intCast(tmp & 0xFF);
        tmp >>= 8;
    }
}

fn mdsMul(state: [WIDTH]u64) [WIDTH]u64 {
    var new_state = [WIDTH]u64{0,0,0};
    for (0..WIDTH) |i| {
        for (0..WIDTH) |j| {
            new_state[i] = fieldAdd(new_state[i], fieldMul(MDS_MATRIX[i][j], state[j]));
        }
    }
    return new_state;
}

fn poseidon2(left: *const [OUTPUT_SIZE]u8, right: *const [OUTPUT_SIZE]u8, out: *[OUTPUT_SIZE]u8) void {
    var state = [WIDTH]u64{ bytesToField(left), bytesToField(right), 0 };
    var rc_idx: usize = 0;

    for (0..FULL_ROUNDS) |_| {
        for (0..WIDTH) |i| state[i] = fieldAdd(state[i], ROUND_CONSTANTS[rc_idx + i]);
        rc_idx += WIDTH;
        for (0..WIDTH) |i| state[i] = fieldPow5(state[i]);
        state = mdsMul(state);
    }

    for (0..PARTIAL_ROUNDS) |_| {
        for (0..WIDTH) |i| state[i] = fieldAdd(state[i], ROUND_CONSTANTS[rc_idx + i]);
        rc_idx += WIDTH;
        state[0] = fieldPow5(state[0]);
        state = mdsMul(state);
    }

    fieldToBytes(state[0], out);
}

inline fn hashPair(left: *const [OUTPUT_SIZE]u8, right: *const [OUTPUT_SIZE]u8, out: *[OUTPUT_SIZE]u8)!void {
    poseidon2(left, right, out);
}

// ============ YOUR MERKLE LOGIC UNCHANGED ============
pub fn computeRoot(allocator: std.mem.Allocator, leaves: []const [OUTPUT_SIZE]u8)![OUTPUT_SIZE]u8 {
    if (leaves.len == 0) return MerkleError.EmptyTree;
    if (leaves.len == 1) return leaves[0];

    var current_tier = try allocator.alloc([OUTPUT_SIZE]u8, leaves.len);
    defer allocator.free(current_tier);
    @memcpy(current_tier, leaves);

    var current_len = leaves.len;
    while (current_len > 1) {
        var next_idx: usize = 0;
        var i: usize = 0;
        while (i < current_len) : (i += 2) {
            if (i + 1 < current_len) {
                try hashPair(&current_tier[i], &current_tier[i + 1], &current_tier[next_idx]);
            } else {
                try hashPair(&current_tier[i], &current_tier[i], &current_tier[next_idx]);
            }
            next_idx += 1;
        }
        current_len = next_idx;
    }
    return current_tier[0];
}

pub fn generateProof(allocator: std.mem.Allocator, leaves: []const [OUTPUT_SIZE]u8, leaf_index: usize)!Proof {
    if (leaves.len == 0) return MerkleError.EmptyTree;
    if (leaf_index >= leaves.len) return MerkleError.LeafNotFound;

    var proof = Proof{.steps = undefined,.len = 0 };
    var current_tier = try allocator.alloc([OUTPUT_SIZE]u8, leaves.len);
    defer allocator.free(current_tier);
    @memcpy(current_tier, leaves);

    var current_len = leaves.len;
    var target_idx = leaf_index;

    while (current_len > 1) {
        const is_odd = (target_idx % 2!= 0);
        const sibling_idx = if (is_odd) target_idx - 1 else target_idx + 1;

        if (sibling_idx < current_len) {
            proof.steps[proof.len] =.{.is_right =!is_odd,.sibling = current_tier[sibling_idx] };
        } else {
            proof.steps[proof.len] =.{.is_right = true,.sibling = current_tier[target_idx] };
        }
        proof.len += 1;

        var next_idx: usize = 0;
        var i: usize = 0;
        while (i < current_len) : (i += 2) {
            if (i + 1 < current_len) {
                try hashPair(&current_tier[i], &current_tier[i + 1], &current_tier[next_idx]);
            } else {
                try hashPair(&current_tier[i], &current_tier[i], &current_tier[next_idx]);
            }
            next_idx += 1;
        }
        current_len = next_idx;
        target_idx /= 2;
    }
    return proof;
}

pub fn verifyProof(leaf: [OUTPUT_SIZE]u8, proof: Proof, expected_root: [OUTPUT_SIZE]u8) bool {
    if (proof.len == 0 or proof.len > MAX_DEPTH) return false;
    var current_hash = leaf;
    var i: usize = 0;
    while (i < proof.len) : (i += 1) {
        const step = proof.steps[i];
        var out_buf: [OUTPUT_SIZE]u8 = undefined;
        if (step.is_right) {
            hashPair(&current_hash, &step.sibling, &out_buf) catch return false;
        } else {
            hashPair(&step.sibling, &current_hash, &out_buf) catch return false;
        }
        current_hash = out_buf;
    }
    return std.mem.eql(u8, &current_hash, &expected_root);
}