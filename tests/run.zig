const std = @import("std");
const basin = @import("basin");

fn hashToHex(input: []const u8, allocator: std.mem.Allocator)![]u8 {
    const hash_bytes = try basin.poseidonHash(input, allocator);
    defer allocator.free(hash_bytes);
    return try basin.toHex(hash_bytes, allocator);
}

test "VECTOR 1: empty" {
    try basin.init(.{ .width = 1, .height = 1, .channels = 1 });
    defer basin.deinit();
    const hex = try hashToHex("", std.testing.allocator);
    defer std.testing.allocator.free(hex);
    try std.testing.expectEqualStrings(
        "d6dbf9be6aed81cbb73693ee366ec5315a9257438e94012caaaaaaaaaaaaaaaa", 
        hex
    );
}

test "VECTOR 2: abc" {
    try basin.init(.{ .width = 1, .height = 1, .channels = 1 });
    defer basin.deinit();
    const hex = try hashToHex("abc", std.testing.allocator);
    defer std.testing.allocator.free(hex);
    try std.testing.expectEqualStrings(
        "126004b8006452630ea03001973ac60014a001cca62f5600aaaaaaaaaaaaaaaa", 
        hex
    );
}

test "VECTOR 3: hello world" {
    try basin.init(.{ .width = 1, .height = 1, .channels = 1 });
    defer basin.deinit();
    const hex = try hashToHex("hello world", std.testing.allocator);
    defer std.testing.allocator.free(hex);
    try std.testing.expectEqualStrings(
        "0e4f1b195d62956fb3a57aa2154e5b0102d2c3e4e4ccf6f7aaaaaaaaaaaaaaaa", 
        hex
    );
}

test "PROP: deterministic" {
    try basin.init(.{ .width = 1, .height = 1, .channels = 1 });
    defer basin.deinit();
    const h1 = try hashToHex("deterministic", std.testing.allocator);
    defer std.testing.allocator.free(h1);
    const h2 = try hashToHex("deterministic", std.testing.allocator);
    defer std.testing.allocator.free(h2);
    try std.testing.expectEqualStrings(h1, h2);
}
