const std = @import("std");
const merkle = @import("merkle");
const basin = @import("basin");

test "Merkle Accumulator: Complete Lifecycle Verification" {
    const allocator = std.testing.allocator;

    // 1. Initialize 4 mock transaction / airdrop leaf variants
    var leaves: [4][32]u8 = undefined;
    @memset(&leaves[0], 0xAA);
    @memset(&leaves[1], 0xBB);
    @memset(&leaves[2], 0xCC);
    @memset(&leaves[3], 0xDD);

    // 2. Compute root commitment
    const root = try merkle.computeRoot(allocator, &leaves);

    // 3. Generate cryptographic proof path for the 3rd leaf ("0xCC")
    const target_index = 2;
    var proof = try merkle.generateProof(allocator, &leaves, target_index);
    defer proof.deinit(); // <- FIX 1: free the allocated steps

    // 4. Verify structural truth of the statement statelessly
    const is_valid = merkle.verifyProof(leaves[target_index], proof, root);
    try std.testing.expect(is_valid);

    // 5. Tamper validation test: modifying proof bytes must trigger failure
    // Need a copy because we can't mutate proof.steps after defer
    var bad_steps = try allocator.alloc(merkle.ProofStep, proof.steps.len);
    defer allocator.free(bad_steps);
    @memcpy(bad_steps, proof.steps);
    bad_steps[0].sibling[0] ^= 0xFF;

    var bad_proof = merkle.MerkleProof{.steps = bad_steps,.allocator = allocator };
    const is_invalid = merkle.verifyProof(leaves[target_index], bad_proof, root);
    try std.testing.expect(!is_invalid);
}