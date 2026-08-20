const std = @import("std");
const merkle = @import("merkle");
const Fr = merkle.Fr; // fr.zig's Fr, re-exported publicly by merkle.zig —
                       // safer than a direct @import("fr"), since we don't
                       // actually know whether "fr" is registered as its
                       // own build module for the tests/ directory.

test "MERKLE: computeRoot basic" {
    const allocator = std.testing.allocator;
    const leaves = [_][]const u8{ "a", "b", "c", "d" };

    const root = try merkle.buildMerkleRoot(&leaves, allocator);
    defer allocator.free(root);

    try std.testing.expectEqual(@as(usize, 32), root.len);

    // Regression pin: once you've independently verified a root value you
    // trust for these exact leaves, hardcode its hex here so any future
    // change that silently alters output gets caught immediately instead
    // of discovered downstream.
    // const expected_hex = "...";
    // const hex = try basin.toHex(root, allocator);
    // defer allocator.free(hex);
    // try std.testing.expectEqualStrings(expected_hex, hex);
}

test "MERKLE: single leaf" {
    const allocator = std.testing.allocator;
    const leaves = [_][]const u8{"only_one"};

    const root = try merkle.buildMerkleRoot(&leaves, allocator);
    defer allocator.free(root);

    try std.testing.expectEqual(@as(usize, 32), root.len);
}

test "MERKLE: same leaves always produce the same root (determinism)" {
    const allocator = std.testing.allocator;
    const leaves = [_][]const u8{ "a", "b", "c", "d" };

    const root1 = try merkle.buildMerkleRoot(&leaves, allocator);
    defer allocator.free(root1);
    const root2 = try merkle.buildMerkleRoot(&leaves, allocator);
    defer allocator.free(root2);

    try std.testing.expectEqualSlices(u8, root1, root2);
}

test "MERKLE: different leaf sets never produce the same root" {
    const allocator = std.testing.allocator;
    const leaves_a = [_][]const u8{ "a", "b", "c" };
    const leaves_b = [_][]const u8{ "a", "b", "c", "c" }; // duplicated last leaf

    const root_a = try merkle.buildMerkleRoot(&leaves_a, allocator);
    defer allocator.free(root_a);
    const root_b = try merkle.buildMerkleRoot(&leaves_b, allocator);
    defer allocator.free(root_b);

    // The actual regression test for the odd-node duplication bug: before
    // the fix, an odd-length tree padded by duplicating its last leaf, so
    // {a,b,c} and {a,b,c,c} could collide on the same root. This test
    // (plus the one below) supersedes the original file's "odd number of
    // leaves" test, which used this same {1,2,3} shape but only checked
    // root.len == 32 — never whether the value was correct or unique.
    try std.testing.expect(!std.mem.eql(u8, root_a, root_b));
}

test "MERKLE: proof round-trip verifies for every leaf, odd tree size" {
    const allocator = std.testing.allocator;
    const leaves = [_][]const u8{ "1", "2", "3" };

    const root = try merkle.buildMerkleRoot(&leaves, allocator);
    defer allocator.free(root);
    var root_arr: [32]u8 = undefined;
    @memcpy(&root_arr, root);

    for (leaves, 0..) |leaf, i| {
        const proof = try merkle.generateProof(&leaves, i, allocator);
        defer allocator.free(proof);

        const valid = try merkle.verifyProof(leaf, proof, root_arr, allocator);
        try std.testing.expect(valid);
    }
}

test "MERKLE: proof fails against a different leaf at the same index" {
    const allocator = std.testing.allocator;
    const leaves = [_][]const u8{ "1", "2", "3" };

    const root = try merkle.buildMerkleRoot(&leaves, allocator);
    defer allocator.free(root);
    var root_arr: [32]u8 = undefined;
    @memcpy(&root_arr, root);

    const proof = try merkle.generateProof(&leaves, 0, allocator);
    defer allocator.free(proof);

    // Real bytes for the wrong leaf, not just a different string — this is
    // the check that would catch a broken/no-op verifier.
    const valid = try merkle.verifyProof("not_the_real_leaf_1", proof, root_arr, allocator);
    try std.testing.expect(!valid);
}

test "FR: multiplication matches a known value, not just 'doesn't crash'" {
    // (P-1) ≡ -1 (mod P), so (P-1)^2 ≡ (-1)^2 = 1 (mod P) — true for ANY
    // prime P, so there's no external vector to trust or get wrong; it's
    // derivable straight from the definition of P. It's exactly the check
    // the widening bug needed: a truncating mul() has no reason to land
    // on 1 for an operand this close to P, since the true product is
    // ~508 bits and only the low 256 survive truncation.
    //
    // Bytes verified against BN254's published modulus, confirmed against
    // an independent implementation before use here. P - 1 only changes
    // the modulus's final byte. This array is that value in LITTLE-endian
    // order, matching how fr.zig's fromBytes reads its input.
    const p_minus_one_bytes: [32]u8 = .{
        0x00, 0x00, 0x00, 0xf0, 0x93, 0xf5, 0xe1, 0x43,
        0x91, 0x70, 0xb9, 0x79, 0x48, 0xe8, 0x33, 0x28,
        0x5d, 0x58, 0x81, 0x81, 0xb6, 0x45, 0x50, 0xb8,
        0x29, 0xa0, 0x31, 0xe1, 0x72, 0x4e, 0x64, 0x30,
    };
    const p_minus_one = Fr.fromBytes(p_minus_one_bytes);
    const result = p_minus_one.mul(p_minus_one);
    try std.testing.expect(result.eq(Fr.one));
}