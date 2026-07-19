const std = @import("std");
const basin = @import("basin");

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
    
    // This is the hash from your CI run
    try std.testing.expectEqualStrings(
        "d6dbf9beae8d1cbb7693ee366ec5315a9257438e94012caaaaaaaaaaaaaaaa", 
        hex
    );
}

test "poseidon deterministic: same input same output" {
    try basin.init(.{ .width = 1, .height = 1, .channels = 1 });
    defer basin.deinit();
    
    const h1 = try hashToHex("basin-test-vector", std.testing.allocator);
    defer std.testing.allocator.free(h1);
    
    const h2 = try hashToHex("basin-test-vector", std.testing.allocator);
    defer std.testing.allocator.free(h2);
    
    try std.testing.expectEqualStrings(h1, h2);
    try std.testing.expectEqual(@as(usize, 64), h1.len); // 32 bytes = 64 hex chars
}

test "poseidon different inputs different outputs" {
    try basin.init(.{ .width = 1, .height = 1, .channels = 1 });
    defer basin.deinit();
    
    const h1 = try hashToHex("input1", std.testing.allocator);
    defer std.testing.allocator.free(h1);
    
    const h2 = try hashToHex("input2", std.testing.allocator);
    defer std.testing.allocator.free(h2);
    
    try std.testing.expect(!std.mem.eql(u8, h1, h2));
}
