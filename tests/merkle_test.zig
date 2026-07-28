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
    defer proof.deinit();

    // 4. Verify structural truth of the statement statelessly
    const is_valid = merkle.verifyProof(leaves[target_index], proof, root);
    try std.testing.expect(is_valid);

    // 5. Tamper validation test: modifying proof bytes must trigger failure
    // Use separate arena so proof.deinit() doesn't free bad_proof's memory
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var bad_steps = try arena_alloc.alloc(merkle.ProofStep, proof.steps.len);
    for (proof.steps, 0..) |s, i| bad_steps[i] = s;
    bad_steps[0].sibling[0] ^= 0xFF; // corrupt first byte of first sibling

    const bad_proof = merkle.MerkleProof{.steps = bad_steps,.allocator = arena_alloc };
    const is_invalid = merkle.verifyProof(leaves[target_index], bad_proof, root);
    try std.testing.expect(!is_invalid);
}