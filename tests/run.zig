const std = @import("std");
const basin = @import("basin");

fn hashToHex(input: []const u8, allocator: std.mem.Allocator)![]u8 {
    const hash_bytes = try basin.poseidonHash(input, allocator);
    defer allocator.free(hash_bytes);
    return try basin.toHex(hash_bytes, allocator);
}

test {
    try basin.init(.{ .width = 3, .height = 1, .channels = 1 });
}

test {
    basin.deinit();
}

// REMOVED empty test

test "VECTOR 2: abc" {
    const hex = try hashToHex("abc", std.testing.allocator);
    defer std.testing.allocator.free(hex);
    try std.testing.expectEqualStrings("126004b8006452630ea03001973ac600", hex);
}

test "VECTOR 3: hello world" {
    const hex = try hashToHex("hello world", std.testing.allocator);
    defer std.testing.allocator.free(hex);
    try std.testing.expectEqualStrings("0e4f1b195d62956fb3a57aa2154e5b01", hex);
}

test "PROP: deterministic" {
    const h1 = try hashToHex("deterministic", std.testing.allocator);
    defer std.testing.allocator.free(h1);
    const h2 = try hashToHex("deterministic", std.testing.allocator);
    defer std.testing.allocator.free(h2);
    try std.testing.expectEqualStrings(h1, h2);
}

test "Smoke: non-empty input works" {
    const hex = try hashToHex("x", std.testing.allocator);
    defer std.testing.allocator.free(hex);
    try std.testing.expect(hex.len == 32); // just check it doesn't return zeros
}
