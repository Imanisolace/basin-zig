const std = @import("std");
const merkle = @import("merkle");

test "Merkle Accumulator: Complete Lifecycle Verification" {
    const allocator = std.testing.allocator;

    var leaves: [4][32]u8 = undefined;
    for (&leaves[0], 0..) |*b, i| b.* = @intCast(i + 1);
    for (&leaves[1], 0..) |*b, i| b.* = @intCast(i + 10);
    for (&leaves[2], 0..) |*b, i| b.* = @intCast(i + 20);
    for (&leaves[3], 0..) |*b, i| b.* = @intCast(i + 30);

    const root = try merkle.computeRoot(allocator, &leaves);
    const target_index = 2;
    var proof = try merkle.generateProof(allocator, &leaves, target_index);
    defer proof.deinit();

    try std.testing.expect(merkle.verifyProof(leaves[target_index], proof, root));

    // Tamper test
    var arena = std.heap.ArenaAllocator.init(allocator); defer arena.deinit();
    var bad_steps = try arena.allocator().alloc(merkle.ProofStep, proof.steps.len);
    @memcpy(bad_steps, proof.steps);
    bad_steps[0].sibling[0] ^= 0xFF; // corrupt

    const bad_proof = merkle.MerkleProof{.steps = bad_steps,.allocator = arena.allocator() };
    const is_invalid = merkle.verifyProof(leaves[target_index], bad_proof, root);
    try std.testing.expect(!is_invalid); // this is line 25 for you
}