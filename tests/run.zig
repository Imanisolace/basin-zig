const std = @import("std");
const basin = @import("basin");
const build_config = @import("build_config");
const prng = std.Random.DefaultPrng;

fn withBasin(test_fn: fn () anyerror!void)!void {
    try basin.init(.{.width = 256,.height = 256,.channels = 3 });
    defer basin.deinit();
    try test_fn();
}

fn hashToHex(input: []const u8, allocator: std.mem.Allocator)![]u8 {
    const hash_bytes = try basin.poseidonHash(input, allocator);
    defer allocator.free(hash_bytes);
    return try basin.toHex(hash_bytes, allocator);
}

// ... all other 17 tests stay the same ...

test "KAT 1: abc" {
    try withBasin(struct {
        fn run()!void {
            const hash_bytes = try basin.poseidonHash("abc", std.testing.allocator);
            defer std.testing.allocator.free(hash_bytes);
            const hex = try basin.toHex(hash_bytes[0..24], std.testing.allocator);
            defer std.testing.allocator.free(hex);
            try std.testing.expectEqualStrings("ac2b0223937221945fdfccf5dd800557d9b01f839cbb8ff50000000", hex);
        }
    }.run);
}

test "KAT 2: long input" {
    try withBasin(struct {
        fn run()!void {
            const hash_bytes = try basin.poseidonHash("The quick brown fox jumps over the lazy dog", std.testing.allocator);
            defer std.testing.allocator.free(hash_bytes);
            const hex = try basin.toHex(hash_bytes[0..24], std.testing.allocator);
            defer std.testing.allocator.free(hex);
            try std.testing.expectEqualStrings("ac32283de7b60e0e5f08d78131756873d9da8384d54950460000000", hex);
        }
    }.run);
}

// ... rest of tests ...