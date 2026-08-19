const std = @import("std");
const basin = @import("basin.zig");
const merkle = @import("merkle.zig");

pub const OUTPUT_SIZE = basin.OUTPUT_SIZE;
pub const MAX_DEPTH = 32;
pub const MAX_LEAVES = 10000;

var global_leaf_buffer: [MAX_LEAVES][OUTPUT_SIZE]u8 = undefined;
var global_root_output: [OUTPUT_SIZE]u8 = undefined;

// has_sibling distinguishes a real pairing from a carried-up odd node —
// the WASM ABI needs this explicit flag since it has no `null`.
const ProofStepWasm = struct {
    has_sibling: bool,
    is_right: bool,
    sibling: [OUTPUT_SIZE]u8,
};

var global_proof_len: usize = 0;
var global_proof_steps: [MAX_DEPTH]ProofStepWasm = undefined;

// Module-level, not a per-call stack array — a 700KB+ local array on
// every export call risked overflowing WASM's (often small) stack.
var arena_buf: [1024 * 900]u8 = undefined;

export fn set_leaf_byte(leaf_idx: usize, byte_idx: usize, value: u8) void {
    if (leaf_idx < MAX_LEAVES and byte_idx < OUTPUT_SIZE) {
        global_leaf_buffer[leaf_idx][byte_idx] = value;
    }
}

fn leafSlices(count: usize, allocator: std.mem.Allocator) ![]const []const u8 {
    const slices = try allocator.alloc([]const u8, count);
    for (0..count) |i| slices[i] = &global_leaf_buffer[i];
    return slices;
}

export fn api_compute_root(count: usize) u32 {
    if (count == 0 or count > MAX_LEAVES) return 0;
    var fba = std.heap.FixedBufferAllocator.init(&arena_buf);
    const allocator = fba.allocator();

    const leaves = leafSlices(count, allocator) catch return 0;
    const root = merkle.buildMerkleRoot(leaves, allocator) catch return 0;
    @memcpy(&global_root_output, root);
    return 1;
}

export fn api_generate_proof(count: usize, leaf_index: usize) u32 {
    if (count == 0 or count > MAX_LEAVES or leaf_index >= count) return 0;
    var fba = std.heap.FixedBufferAllocator.init(&arena_buf);
    const allocator = fba.allocator();

    const leaves = leafSlices(count, allocator) catch return 0;
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

export fn api_verify_proof(
    leaf_ptr: [*]const u8,
    root_ptr: [*]const u8,
    proof_len: usize,
    siblings_ptr: [*]const u8,
    is_right_ptr: [*]const u8,
    has_sibling_ptr: [*]const u8, // new — required to reconstruct carry-up steps correctly
) u32 {
    if (proof_len == 0 or proof_len > MAX_DEPTH) return 0;
    var fba = std.heap.FixedBufferAllocator.init(&arena_buf);
    const allocator = fba.allocator();

    const steps = allocator.alloc(merkle.ProofStep, proof_len) catch return 0;
    for (0..proof_len) |i| {
        var sib: [OUTPUT_SIZE]u8 = undefined;
        @memcpy(&sib, siblings_ptr[i * OUTPUT_SIZE ..][0..OUTPUT_SIZE]);
        steps[i] = .{
            .sibling = if (has_sibling_ptr[i] != 0) sib else null,
            .is_right = is_right_ptr[i] != 0,
        };
    }

    var root: [OUTPUT_SIZE]u8 = undefined;
    @memcpy(&root, root_ptr[0..OUTPUT_SIZE]);

    const ok = merkle.verifyProof(leaf_ptr[0..OUTPUT_SIZE], steps, root, allocator) catch return 0;
    return if (ok) 1 else 0;
}

export fn get_root_ptr() [*]u8 { return &global_root_output; }
export fn get_proof_len() usize { return global_proof_len; }
export fn get_proof_step_side(idx: usize) u32 { return if (global_proof_steps[idx].is_right) 1 else 0; }
export fn get_proof_step_has_sibling(idx: usize) u32 { return if (global_proof_steps[idx].has_sibling) 1 else 0; }
export fn get_proof_step_sibling_ptr(idx: usize) [*]u8 { return &global_proof_steps[idx].sibling; }