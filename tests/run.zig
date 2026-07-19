const std = @import("std");
const basin = @import("../src/basin.zig");

fn hashToHex(input: []const u8, allocator: std.mem.Allocator)![]u8 {
    const hash_bytes = try basin.poseidonHash(input, allocator);
    defer allocator.free(hash_bytes);
    return try basin.toHex(hash_bytes, allocator);
}

test "poseidon vector: empty" {
    try basin.init(.{ .width = 1, .height = 1, .channels = 1 });
    defer basin.deinit();
    const hex = try hashToHex("", std.testing.allocator);
    defer std.testing.allocator.free(hex);
    try std.testing.expectEqualStrings("RUN_ONCE_TO_GET_THIS", hex);
}

test "poseidon vector: abc" {
    try basin.init(.{ .width = 1, .height = 1, .channels = 1 });
    defer basin.deinit();
    const hex = try hashToHex("abc", std.testing.allocator);
    defer std.testing.allocator.free(hex);
    try std.testing.expectEqualStrings("RUN_ONCE_TO_GET_THIS", hex);
}

test "poseidon deterministic" {
    try basin.init(.{ .width = 1, .height = 1, .channels = 1 });
    defer basin.deinit();
    const h1 = try hashToHex("same", std.testing.allocator);
    defer std.testing.allocator.free(h1);
    const h2 = try hashToHex("same", std.testing.allocator);
    defer std.testing.allocator.free(h2);
    try std.testing.expectEqualStrings(h1, h2);
}
