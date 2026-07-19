const std = @import("std");
const basin = @import("basin");

fn hashToHex(input: []const u8, allocator: std.mem.Allocator)![]u8 {
    const hash_bytes = try basin.poseidonHash(input, allocator);
    defer allocator.free(hash_bytes);
    return try basin.toHex(hash_bytes, allocator);
}

// Official test vectors - lock these in
test "vector: empty string" {
    try basin.init(.{ .width = 1, .height = 1, .channels = 1 });
    defer basin.deinit();
    
    const hex = try hashToHex("", std.testing.allocator);
    defer std.testing.allocator.free(hex);
    
    try std.testing.expectEqualStrings(
        "d6dbf9be6aed81cbb73693ee366ec5315a9257438e94012caaaaaaaaaaaaaaaa", 
        hex
    );
}

test "vector: abc" {
    try basin.init(.{ .width = 1, .height = 1, .channels = 1 });
    defer basin.deinit();
    
    const hex = try hashToHex("abc", std.testing.allocator);
    defer std.testing.allocator.free(hex);
    
    // Run once to get this, then paste it here
    try std.testing.expectEqualStrings("TODO_RUN_ONCE_FOR_ABC", hex);
}

test "vector: hello world" {
    try basin.init(.{ .width = 1, .height = 1, .channels = 1 });
    defer basin.deinit();
    
    const hex = try hashToHex("hello world", std.testing.allocator);
    defer std.testing.allocator.free(hex);
    
    // Run once to get this, then paste it here
    try std.testing.expectEqualStrings("TODO_RUN_ONCE_FOR_HELLO", hex);
}

test "vector: 1kb data" {
    try basin.init(.{ .width = 1, .height = 1, .channels = 1 });
    defer basin.deinit();
    
    const data = try std.testing.allocator.alloc(u8, 1024);
    defer std.testing.allocator.free(data);
    @memset(data, 'A');
    
    const hex = try hashToHex(data, std.testing.allocator);
    defer std.testing.allocator.free(hex);
    
    // Run once to get this, then paste it here
    try std.testing.expectEqualStrings("TODO_RUN_ONCE_FOR_1KB", hex);
}

// Property tests
test "property: deterministic" {
    try basin.init(.{ .width = 1, .height = 1, .channels = 1 });
    defer basin.deinit();
    
    const input = "same input 100 times";
    var i: usize = 0;
    var first_hash: []u8 = undefined;
    
    while (i < 100) : (i += 1) {
        const h = try hashToHex(input, std.testing.allocator);
        if (i == 0) {
            first_hash = h;
        } else {
            defer std.testing.allocator.free(h);
            try std.testing.expectEqualStrings(first_hash, h);
        }
    }
    defer std.testing.allocator.free(first_hash);
}

test "property: avalanche - 1 bit flip" {
    try basin.init(.{ .width = 1, .height = 1, .channels = 1 });
    defer basin.deinit();
    
    const h1 = try hashToHex("test", std.testing.allocator);
    defer std.testing.allocator.free(h1);
    
    const h2 = try hashToHex("tesu", std.testing.allocator); // 1 char diff
    defer std.testing.allocator.free(h2);
    
    try std.testing.expect(!std.mem.eql(u8, h1, h2));
}

test "property: output length always 64 hex chars" {
    try basin.init(.{ .width = 1, .height = 1, .channels = 1 });
    defer basin.deinit();
    
    const inputs = [_][]const u8{ "", "a", "longer string to test", "1234567890" };
    for (inputs) |input| {
        const hex = try hashToHex(input, std.testing.allocator);
        defer std.testing.allocator.free(hex);
        try std.testing.expectEqual(@as(usize, 64), hex.len); // 32 bytes
    }
}

test "property: init/deinit multiple times" {
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        try basin.init(.{ .width = 1, .height = 1, .channels = 1 });
        const hex = try hashToHex("test", std.testing.allocator);
        std.testing.allocator.free(hex);
        basin.deinit();
    }
}
