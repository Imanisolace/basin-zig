const std = @import("std");
const basin = @import("basin");

fn hashToHex(input: []const u8, allocator: std.mem.Allocator)![]u8 {
    const hash_bytes = try basin.poseidonHash(input, allocator);
    defer allocator.free(hash_bytes);
    return try basin.toHex(hash_bytes, allocator);
}

test "vector: empty" {
    try basin.init(.{ .width = 1, .height = 1, .channels = 1 });
    defer basin.deinit();
    const hex = try hashToHex("", std.testing.allocator);
    defer std.testing.allocator.free(hex);
    
    // This WILL fail until you put the real hash here
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
    
    // Deliberately wrong. First run will fail and print the real hash
    try std.testing.expectEqualStrings("WRONG_HASH_TO_FORCE_FAILURE", hex);
}        } else {
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
