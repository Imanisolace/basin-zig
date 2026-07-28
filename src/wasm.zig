const std = @import("std");
const basin = @import("basin.zig");

pub const OUTPUT_SIZE = basin.OUTPUT_SIZE;
pub const MAX_DEPTH = 32;

// Statically reserved buffers inside Wasm linear memory
var global_leaf_buffer: [10000][OUTPUT_SIZE]u8 = undefined;
var global_root_output: [OUTPUT_SIZE]u8 = undefined;

const ProofStepWasm = struct {
    is_right: bool,
    sibling: [OUTPUT_SIZE]u8,
};

var global_proof_len: usize = 0;
var global_proof_steps: [MAX_DEPTH]ProofStepWasm = undefined;

/// Write 1 byte into a leaf slot. Called by JS
export fn set_leaf_byte(leaf_idx: usize, byte_idx: usize, value: u8) void {
    if (leaf_idx < 10000 and byte_idx < OUTPUT_SIZE) {
        global_leaf_buffer[leaf_idx][byte_idx] = value;
    }
}

/// Compute merkle root from loaded leaves. Returns 1 on success, 0 on fail
export fn api_compute_root(count: usize) u32 {
    if (count == 0 or count > 10000) return 0;

    var arena_buf: [1024 * 700]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&arena_buf);
    const allocator = fba.allocator();

    var current_tier = allocator.alloc([OUTPUT_SIZE]u8, count) catch return 0;
    for (0..count) |i| current_tier[i] = global_leaf_buffer[i];

    var current_len = count;
    while (current_len > 1) {
        var next_idx: usize = 0;
        var i: usize = 0;
        while (i < current_len) : (i += 2) {
            var h = basin.Hasher.init();
            if (i + 1 < current_len) {
                h.update(&current_tier[i]);
                h.update(&current_tier[i + 1]);
            } else {
                h.update(&current_tier[i]);
                h.update(&current_tier[i]);
            }
            h.final(&current_tier[next_idx]);
            next_idx += 1;
        }
        current_len = next_idx;
    }

    global_root_output = current_tier[0];
    return 1;
}

/// Generate proof path. Returns 1 on success, 0 on fail
export fn api_generate_proof(count: usize, leaf_index: usize) u32 {
    if (count == 0 or count > 10000 or leaf_index >= count) return 0;

    var arena_buf: [1024 * 700]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&arena_buf);
    const allocator = fba.allocator();

    var current_tier = allocator.alloc([OUTPUT_SIZE]u8, count) catch return 0;
    for (0..count) |i| current_tier[i] = global_leaf_buffer[i];

    var current_len = count;
    var target_idx = leaf_index;
    var depth: usize = 0;

    while (current_len > 1) {
        const is_odd = (target_idx % 2 != 0);
        const sibling_idx = if (is_odd) target_idx - 1 else target_idx + 1;

        if (sibling_idx < current_len) {
            global_proof_steps[depth] =.{
               .is_right =!is_odd,
               .sibling = current_tier[sibling_idx],
            };
        } else {
            global_proof_steps[depth] =.{
               .is_right = true,
               .sibling = current_tier[target_idx],
            };
        }
        depth += 1;

        var next_idx: usize = 0;
        var i: usize = 0;
        while (i < current_len) : (i += 2) {
            var h = basin.Hasher.init();
            if (i + 1 < current_len) {
                h.update(&current_tier[i]);
                h.update(&current_tier[i + 1]);
            } else {
                h.update(&current_tier[i]);
                h.update(&current_tier[i]);
            }
            h.final(&current_tier[next_idx]);
            next_idx += 1;
        }
        current_len = next_idx;
        target_idx /= 2;
    }

    global_proof_len = depth;
    return 1;
}

/// Verify a proof. Returns 1 if valid, 0 if invalid
export fn api_verify_proof(
    leaf_ptr: [*]const u8,
    root_ptr: [*]const u8,
    proof_len: usize,
    siblings_ptr: [*]const u8,
    is_right_ptr: [*]const u8,
) u32 {
    if (proof_len == 0 or proof_len > MAX_DEPTH) return 0;

    var current_hash: [OUTPUT_SIZE]u8 = undefined;
    @memcpy(&current_hash, leaf_ptr[0..OUTPUT_SIZE]);

    var expected_root: [OUTPUT_SIZE]u8 = undefined;
    @memcpy(&expected_root, root_ptr[0..OUTPUT_SIZE]);

    var sibling_buf: [OUTPUT_SIZE]u8 = undefined;
    for (0..proof_len) |i| {
        const sibling_offset = i * OUTPUT_SIZE;
        @memcpy(&sibling_buf, siblings_ptr[sibling_offset..][0..OUTPUT_SIZE]);
        const is_right = is_right_ptr[i] != 0;

        var h = basin.Hasher.init();
        if (is_right) {
            h.update(&current_hash);
            h.update(&sibling_buf);
        } else {
            h.update(&sibling_buf);
            h.update(&current_hash);
        }
        h.final(&current_hash);
    }

    return if (std.mem.eql(u8, &current_hash, &expected_root)) 1 else 0;
}

/// Exports for JS to read results from WASM memory
export fn get_root_ptr() [*]u8 { return &global_root_output; }
export fn get_proof_len() usize { return global_proof_len; }
export fn get_proof_step_side(idx: usize) u32 { return if (global_proof_steps[idx].is_right) 1 else 0; }
export fn get_proof_step_sibling_ptr(idx: usize) [*]u8 { return &global_proof_steps[idx].sibling; }