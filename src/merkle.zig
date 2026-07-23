const std = @import("std");
const basin = @import("basin");

pub const OUTPUT_SIZE = basin.OUTPUT_SIZE;

pub const MerkleError = error{
    EmptyTree,
    LeafNotFound,
    InvalidProofLength,
};

/// A single step in a Merkle verification path
pub const ProofStep = struct {
    /// True if the sibling sits on the right side of the current path index
    is_right: bool,
    /// Sibling hash data
    sibling: [OUTPUT_SIZE]u8,
};

/// Maximum depth supported by this fixed proof buffer stack (2^32 max leaves)
pub const MAX_DEPTH = 32;

pub const Proof = struct {
    steps: [MAX_DEPTH]ProofStep,
    len: usize,
};

/// Computes the master Merkle Root out of an array of leaves inline.
/// Uses the exact duplicate-odd-leaf pattern required by standard cryptographic trees.
pub fn computeRoot(allocator: std.mem.Allocator, leaves: []const [OUTPUT_SIZE]u8) ![OUTPUT_SIZE]u8 {
    if (leaves.len == 0) return MerkleError.EmptyTree;
    if (leaves.len == 1) return leaves[0];

    // Allocate an active processing tier layer
    var current_tier = try allocator.alloc([OUTPUT_SIZE]u8, leaves.len);
    defer allocator.free(current_tier);
    @memcpy(current_tier, leaves);

    var current_len = leaves.len;
    while (current_len > 1) {
        var next_idx: usize = 0;
        var i: usize = 0;

        while (i < current_len) : (i += 2) {
            if (i + 1 < current_len) {
                // Combine left and right sibling pairs
                try hashPair(&current_tier[i], &current_tier[i + 1], &current_tier[next_idx]);
            } else {
                // Odd element duplication rule
                try hashPair(&current_tier[i], &current_tier[i], &current_tier[next_idx]);
            }
            next_idx += 1;
        }
        current_len = next_idx;
    }

    return current_tier[0];
}

/// Generates a step-by-step cryptographic audit path proving leaf inclusion
pub fn generateProof(allocator: std.mem.Allocator, leaves: []const [OUTPUT_SIZE]u8, leaf_index: usize) !Proof {
    if (leaves.len == 0) return MerkleError.EmptyTree;
    if (leaf_index >= leaves.len) return MerkleError.LeafNotFound;

    var proof = Proof{
        .steps = undefined,
        .len = 0,
    };

    var current_tier = try allocator.alloc([OUTPUT_SIZE]u8, leaves.len);
    defer allocator.free(current_tier);
    @memcpy(current_tier, leaves);

    var current_len = leaves.len;
    var target_idx = leaf_index;

    while (current_len > 1) {
        const is_odd = (target_idx % 2 != 0);
        const sibling_idx = if (is_odd) target_idx - 1 else target_idx + 1;

        if (sibling_idx < current_len) {
            proof.steps[proof.len] = ProofStep{
                .is_right = !is_odd,
                .sibling = current_tier[sibling_idx],
            };
        } else {
            // Sibling is out of bounds, duplicate self for odd boundary
            proof.steps[proof.len] = ProofStep{
                .is_right = true,
                .sibling = current_tier[target_idx],
            };
        }
        proof.len += 1;

        // Compress tier layout upwards
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

/// Verifies a proof path statelessly. Requires NO dynamic memory allocations.
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

/// Helper function to hash two independent leaves inside a standard width-3 absorption block
inline fn hashPair(left: *const [OUTPUT_SIZE]u8, right: *const [OUTPUT_SIZE]u8, out: *[OUTPUT_SIZE]u8) !void {
    var h = basin.Hasher.init();
    h.update(left);
    h.update(right);
    h.final(out);
}
