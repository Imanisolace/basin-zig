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
    const proof = try merkle.generateProof(allocator, &leaves, target_index);

    // 4. Verify structural truth of the statement statelessly
    const is_valid = merkle.verifyProof(leaves[target_index], proof, root);
    try std.testing.expect(is_valid);

    // 5. Tamper validation test: modifying proof bytes must trigger failure
    var bad_proof = proof;
    bad_proof.steps[0].sibling[0] ^= 0xFF;
    const is_invalid = merkle.verifyProof(leaves[target_index], bad_proof, root);
    try std.testing.expect(!is_invalid);
}