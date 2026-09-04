const std = @import("std");
const basin = @import("basin");
const merkle = @import("merkle");

pub const OUTPUT_SIZE = basin.OUTPUT_SIZE;
pub const MAX_DEPTH = 32;
pub const MAX_LEAVES = 10000;
pub const MAX_LEAF_DATA = 1024 * 1024 * 8; // 8MB packed buffer for all leaf bytes combined
pub const MAX_VERIFY_LEAF = 65536; // cap on a single leaf being verified

// --- Leaf storage: flat buffer + offset/length table, not fixed slots ---
var global_leaf_data: [MAX_LEAF_DATA]u8 = undefined;
var global_leaf_offset: [MAX_LEAVES]usize = undefined;
var global_leaf_len: [MAX_LEAVES]usize = undefined;
var global_leaf_count: usize = 0;
var global_write_cursor: usize = 0;

var global_root_output: [OUTPUT_SIZE]u8 = undefined;

// has_sibling distinguishes a real pairing from a carried-up odd node.
const ProofStepWasm = struct {
    has_sibling: bool,
    is_right: bool,
    sibling: [OUTPUT_SIZE]u8,
};
var global_proof_len: usize = 0;
var global_proof_steps: [MAX_DEPTH]ProofStepWasm = undefined;

// --- Verify scratch: leaf here is variable length too ---
var global_verify_leaf: [MAX_VERIFY_LEAF]u8 = undefined;
var global_verify_leaf_len: usize = 0;
var global_verify_root: [OUTPUT_SIZE]u8 = undefined;
var global_verify_siblings: [MAX_DEPTH][OUTPUT_SIZE]u8 = undefined;
var global_verify_is_right: [MAX_DEPTH]u8 = undefined;
var global_verify_has_sibling: [MAX_DEPTH]u8 = undefined;

// Working arena for tree construction. 
var arena_buf: [1024 * 1536]u8 = undefined;

/// Clear all loaded leaves. Call before loading a new leaf set.
export fn reset_leaves() void {
    global_leaf_count = 0;
    global_write_cursor = 0;
}

/// Reserve space for a leaf of `len` bytes. Returns its index (0-based,
/// assigned in call order) or -1 if there's no room. Call once per leaf,
/// in order, then write the leaf's bytes via get_leaf_write_ptr().
export fn begin_leaf(len: usize) i32 {
    if (global_leaf_count >= MAX_LEAVES) return -1;
    if (global_write_cursor + len > MAX_LEAF_DATA) return -1;

    const idx = global_leaf_count;
    global_leaf_offset[idx] = global_write_cursor;
    global_leaf_len[idx] = len;
    global_write_cursor += len;
    global_leaf_count += 1;
    return @intCast(idx);
}

/// Pointer to write `len` bytes into for leaf `idx` (same `len` passed
/// to begin_leaf for that index).
export fn get_leaf_write_ptr(idx: usize) [*]u8 {
    return global_leaf_data[global_leaf_offset[idx]..].ptr;
}

fn leafSlices(allocator: std.mem.Allocator) ![]const []const u8 {
    const slices = try allocator.alloc([]const u8, global_leaf_count);
    for (0..global_leaf_count) |i| {
        const off = global_leaf_offset[i];
        const len = global_leaf_len[i];
        slices[i] = global_leaf_data[off..][0..len];
    }
    return slices;
}

/// Compute the Merkle root from the currently loaded leaves.
export fn api_compute_root() u32 {
    if (global_leaf_count == 0) return 0;
    var fba = std.heap.FixedBufferAllocator.init(&arena_buf);
    const allocator = fba.allocator();

    const leaves = leafSlices(allocator) catch return 0;
    const root = merkle.buildMerkleRoot(leaves, allocator) catch return 0;
    @memcpy(&global_root_output, root);
    return 1;
}

/// Generate a Merkle proof for the leaf at `leaf_index`.
export fn api_generate_proof(leaf_index: usize) u32 {
    if (global_leaf_count == 0 or leaf_index >= global_leaf_count) return 0;
    var fba = std.heap.FixedBufferAllocator.init(&arena_buf);
    const allocator = fba.allocator();

    const leaves = leafSlices(allocator) catch return 0;
    const proof = merkle.generateProof(leaves, leaf_index, allocator) catch return 0;
    if (proof.len > MAX_DEPTH) return 0;

    for (proof, 0..) |step, i| {
        global_proof_steps[i] = .{
            .has_sibling = step.sibling != null,
            .is_right = step.is_right,
            .sibling = step.sibling orelse [_]u8{0} ** OUTPUT_SIZE,
        };
    }
    global_proof_len = proof.len;
    return 1;
}

/// Max size of a single leaf that can be verified. JS should check
/// against this before calling get_verify_leaf_ptr.
export fn verify_leaf_capacity() usize { return MAX_VERIFY_LEAF; }

/// Reserve space to write the leaf being verified. Caller must have
/// already checked len <= verify_leaf_capacity().
export fn get_verify_leaf_ptr(len: usize) [*]u8 {
    global_verify_leaf_len = @min(len, MAX_VERIFY_LEAF);
    return &global_verify_leaf;
}

export fn get_verify_root_ptr() [*]u8 { return &global_verify_root; }
export fn get_verify_siblings_ptr() [*]u8 { return @ptrCast(&global_verify_siblings); }
export fn get_verify_is_right_ptr() [*]u8 { return &global_verify_is_right; }
export fn get_verify_has_sibling_ptr() [*]u8 { return &global_verify_has_sibling; }

export fn api_verify_proof(proof_len: usize) u32 {
    if (proof_len == 0 or proof_len > MAX_DEPTH) return 0;
    if (global_verify_leaf_len == 0) return 0;
    var fba = std.heap.FixedBufferAllocator.init(&arena_buf);
    const allocator = fba.allocator();

    const steps = allocator.alloc(merkle.ProofStep, proof_len) catch return 0;
    for (0..proof_len) |i| {
        steps[i] = .{
            .sibling = if (global_verify_has_sibling[i] != 0) global_verify_siblings[i] else null,
            .is_right = global_verify_is_right[i] != 0,
        };
    }

    const leaf = global_verify_leaf[0..global_verify_leaf_len];
    const ok = merkle.verifyProof(leaf, steps, global_verify_root, allocator) catch return 0;
    return if (ok) 1 else 0;
}

export fn get_root_ptr() [*]u8 { return &global_root_output; }
export fn get_proof_len() usize { return global_proof_len; }
export fn get_proof_step_side(idx: usize) u32 { return if (global_proof_steps[idx].is_right) 1 else 0; }
export fn get_proof_step_has_sibling(idx: usize) u32 { return if (global_proof_steps[idx].has_sibling) 1 else 0; }
export fn get_proof_step_sibling_ptr(idx: usize) [*]u8 { return &global_proof_steps[idx].sibling; }