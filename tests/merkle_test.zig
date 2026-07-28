const std = @import("std");
const merkle = @import("merkle");
const basin = @import("basin");

test "MERKLE: computeRoot basic" {
    const allocator = std.testing.allocator;
    const leaves = [_][]const u8{ "a", "b", "c", "d" };

    const root = try merkle.buildMerkleRoot(&leaves, allocator); // FIX: was computeRoot
    defer allocator.free(root);

    try std.testing.expectEqual(@as(usize, 32), root.len);
    
    const hex = try basin.toHex(root, allocator);
    defer allocator.free(hex);
    std.debug.print("\nOld test root: {s}\n", .{hex});
}

test "MERKLE: single leaf" {
    const allocator = std.testing.allocator;
    const leaves = [_][]const u8{"only_one"};

    const root = try merkle.buildMerkleRoot(&leaves, allocator);
    defer allocator.free(root);

    try std.testing.expectEqual(@as(usize, 32), root.len);
}

test "MERKLE: odd number of leaves" {
    const allocator = std.testing.allocator;
    const leaves = [_][]const u8{ "1", "2", "3" };

    const root = try merkle.buildMerkleRoot(&leaves, allocator);
    defer allocator.free(root);

    try std.testing.expectEqual(@as(usize, 32), root.len);
}