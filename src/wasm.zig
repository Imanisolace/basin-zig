const std = @import("std");
const basin = @import("basin.zig");

pub const OUTPUT_SIZE = basin.OUTPUT_SIZE;
pub const MAX_DEPTH = 32;

// 1. Statically reserved buffers inside Wasm linear memory
// Supports trees up to 10,000 leaves without runtime OS memory management
var global_leaf_buffer: [10000][OUTPUT_SIZE]u8 = undefined;
var global_root_output: [OUTPUT_SIZE]u8 = undefined;

// Emulate a fixed-size proof stack structure matching merkle.zig definitions
const ProofStepWasm = struct {
    is_right: bool,
    sibling: [OUTPUT_SIZE]u8,
};

var global_proof_len: usize = 0;
var global_proof_steps: [MAX_DEPTH]ProofStepWasm = undefined;

/// Allocation-free export allowing the host JS runtime to write directly to our static array
export fn set_leaf_byte(leaf_idx: usize, byte_idx: usize, value: u8) void {
    if (leaf_idx < 10000 and byte_idx < OUTPUT_SIZE) {
        global_leaf_buffer[leaf_idx][byte_idx] = value;
    }
}

/// Computes the tree's master Merkle Root out of the loaded buffer segment
export fn api_compute_root(count: usize) bool {
    if (count == 0 or count > 10000) return false;

    // Allocate a scratch buffer for compute operations on the stack instead of heap
    var arena_buf: [1024 * 700]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&arena_buf);
    const allocator = fba.allocator();

    // Perform internal compute loops through the underlying standard library core
    var current_tier = allocator.alloc([OUTPUT_SIZE]u8, count) catch return false;
    
    // Using explicit loop copy for standard compatibility across slices/arrays
    for (0..count) |i| {
        current_tier[i] = global_leaf_buffer[i];
    }

    var current_len = count;
    while (current_len > 1) {
        var next_idx: usize = 0;
        var i: usize = 0;

        while (i < current_len) : (i += 2) {
            if (i + 1 < current_len) {
                var h = basin.Hasher.init();
                h.update(&current_tier[i]);
                h.update(&current_tier[i + 1]);
                h.final(&current_tier[next_idx]);
            } else {
                var h = basin.Hasher.init();
                h.update(&current_tier[i]);
                h.update(&current_tier[i]);
                h.final(&current_tier[next_idx]);
            }
            next_idx += 1;
        }
        current_len = next_idx;
    }

    global_root_output = current_tier[0];
    return true;
}

/// Generates a proof layout path mapping inside the statically reserved proof structures
export fn api_generate_proof(count: usize, leaf_index: usize) bool {
    // Strictly enforces bounds to prevent arbitrary out-of-bounds crashes
    if (count == 0 or count > 10000 or leaf_index >= count) return false;

    var arena_buf: [1024 * 700]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&arena_buf);
    const allocator = fba.allocator();

    var current_tier = allocator.alloc([OUTPUT_SIZE]u8, count) catch return false;
    for (0..count) |i| {
        current_tier[i] = global_leaf_buffer[i];
    }

    var current_len = count;
    var target_idx = leaf_index;
    var depth: usize = 0;

    while (current_len > 1) {
        const is_odd = (target_idx % 2 != 0);
        const sibling_idx = if (is_odd) target_idx - 1 else target_idx + 1;

        if (sibling_idx < current_len) {
            global_proof_steps[depth] = ProofStepWasm{
                .is_right = !is_odd,
                .sibling = current_tier[sibling_idx],
            };
        } else {
            global_proof_steps[depth] = ProofStepWasm{
                .is_right = true,
                .sibling = current_tier[target_idx],
            };
        }
        depth += 1;

        var next_idx: usize = 0;
        var i: usize = 0;
        while (i < current_len) : (i += 2) {
            if (i + 1 < current_len) {
                var h = basin.Hasher.init();
                h.update(&current_tier[i]);
                h.update(&current_tier[i + 1]);
                h.final(&current_tier[next_idx]);
            } else {
                var h = basin.Hasher.init();
                h.update(&current_tier[i]);
                h.update(&current_tier[i]);
                h.final(&current_tier[next_idx]);
            }
            next_idx += 1;
        }
        current_len = next_idx;
        target_idx /= 2;
    }

    global_proof_len = depth;
    return true;
}

// 2. Linear memory pointer exports for JS host bindings
export fn get_root_ptr() [*]u8 { return &global_root_output; }
export fn get_proof_len() usize { return global_proof_len; }
export fn get_proof_step_side(idx: usize) bool { return global_proof_steps[idx].is_right; }
export fn get_proof_step_sibling_ptr(idx: usize) [*]u8 { return &global_proof_steps[idx].sibling; }
