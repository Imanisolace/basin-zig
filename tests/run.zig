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
    
    // Official vector from your local run
    try std.testing.expectEqualStrings(
        "d6dbf9be6aed81cbb73693ee366ec5315a9257438e94012caaaaaaaaaaaaaaaa", 
        hex
    );
}

test "poseidon vector: abc" {
    try basin.init(.{ .width = 1, .height = 1, .channels = 1 });
    defer basin.deinit();
    
    const hex = try hashToHex("abc", std.testing.allocator);
    defer std.testing.allocator.free(hex);
    
    // Run once to get this, then lock it
    try std.testing.expectEqualStrings("TODO_RUN_ONCE", hex);
}

test "deterministic: same input same output" {
    try basin.init(.{ .width = 1, .height = 1, .channels = 1 });
    defer basin.deinit();
    
    const h1 = try hashToHex("basin-test", std.testing.allocator);
    defer std.testing.allocator.free(h1);
    
    const h2 = try hashToHex("basin-test", std.testing.allocator);
    defer std.testing.allocator.free(h2);
    
    try std.testing.expectEqualStrings(h1, h2);
    try std.testing.expectEqual(@as(usize, 64), h1.len); // 32 bytes
}

test "avalanche: different inputs different outputs" {
    try basin.init(.{ .width = 1, .height = 1, .channels = 1 });
    defer basin.deinit();
    
    const h1 = try hashToHex("a", std.testing.allocator);
    defer std.testing.allocator.free(h1);
    
    const h2 = try hashToHex("b", std.testing.allocator);
    defer std.testing.allocator.free(h2);
    
    try std.testing.expect(!std.mem.eql(u8, h1, h2));
}
