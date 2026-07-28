const std = @import("std");
const merkle = @import("merkle");

test "Merkle Accumulator: Complete Lifecycle Verification" {
    const allocator = std.testing.allocator;
    var leaves: [4][32]u8 = undefined;
    @memset(&leaves[0], 0xAA); @memset(&leaves[1], 0xBB); @memset(&leaves[2], 0xCC); @memset(&leaves[3], 0xDD);

    const root = try merkle.computeRoot(allocator, &leaves);
    const target_index = 2;
    var proof = try merkle.generateProof(allocator, &leaves, target_index);
    defer proof.deinit();

    const is_valid = merkle.verifyProof(leaves[target_index], target_index, proof, root); // pass index
    try std.testing.expect(is_valid);

    var arena = std.heap.ArenaAllocator.init(allocator); defer arena.deinit();
    const arena_alloc = arena.allocator();
    var bad_steps = try arena_alloc.alloc(merkle.ProofStep, proof.steps.len);
    for (proof.steps, 0..) |s, i| bad_steps[i] = s;
    bad_steps[0].sibling[0] ^= 0xFF;

    const bad_proof = merkle.MerkleProof{.steps = bad_steps,.allocator = arena_alloc };
    const is_invalid = merkle.verifyProof(leaves[target_index], target_index, bad_proof, root); // pass index
    try std.testing.expect(!is_invalid);
}