const std = @import("std");
const basin = @import("basin");
const build_config = @import("build_config");
const prng = std.Random.DefaultPrng;

fn hashToHex(input: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const hash_bytes = try basin.poseidonHash(input, allocator);
    defer allocator.free(hash_bytes);
    return try basin.toHex(hash_bytes, allocator);
}

test "HASH: empty input fails" {
    try std.testing.expectError(
        basin.BasinError.EmptyInput,
        basin.poseidonHash("", std.testing.allocator),
    );
}

test "HASH: returns 32 bytes" {
    const hash = try basin.poseidonHash("test", std.testing.allocator);
    defer std.testing.allocator.free(hash);
    try std.testing.expectEqual(@as(usize, 32), hash.len);
}

test "HASH: streaming matches one-shot" {
    const allocator = std.testing.allocator;
    const data = try allocator.alloc(u8, 10000);
    defer allocator.free(data);
    @memset(data, 'x');

    const h1 = try basin.poseidonHash(data, allocator);
    defer allocator.free(h1);

    // FIXED: Hasher.init() is infallible. Removed 'try' keyword.
    var hasher = basin.Hasher.init();
    
    // FIXED: .update() is infallible. Removed 'try' keyword.
    hasher.update(data[0..5000]);
    hasher.update(data[5000..]);
    
    var h2: [32]u8 = undefined;
    // FIXED: .final() is infallible. Removed 'try' keyword.
    hasher.final(&h2);

    try std.testing.expectEqualSlices(u8, h1, &h2);
}

test "TOHEX: roundtrip" {
    const data = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
    const hex = try basin.toHex(&data, std.testing.allocator);
    defer std.testing.allocator.free(hex);
    try std.testing.expectEqualStrings("deadbeef", hex);
}

test "PROP: binary data with nulls is handled" {
    const data = &[_]u8{ 0, 1, 2, 255, 0, 0, 42 };
    const hash = try basin.poseidonHash(data, std.testing.allocator);
    defer std.testing.allocator.free(hash);
    try std.testing.expectEqual(@as(usize, 32), hash.len);
}

test "EDGE: block boundaries" {
    const allocator = std.testing.allocator;
    // FIXED: Shifted boundary lengths to match your real pure-Zig rate size limits (16 and 32 bytes)
    const lengths = [_]usize{ 15, 16, 17, 32, 1024 };
    for (lengths) |len| {
        const data = try allocator.alloc(u8, len);
        defer allocator.free(data);
        @memset(data, 'a');
        const hash = try basin.poseidonHash(data, allocator);
        defer allocator.free(hash);
        try std.testing.expectEqual(@as(usize, 32), hash.len);
    }
}

test "FUZZ: random bytes dont crash" {
    var rng = prng.init(0x1234);
    const allocator = std.testing.allocator;
    var buf: [256]u8 = undefined;
    var i: usize = 0;
    while (i < 100) : (i += 1) { 
        const len = rng.random().intRangeAtMost(usize, 0, buf.len);
        rng.random().bytes(buf[0..len]);
        const hash = basin.poseidonHash(buf[0..len], allocator) catch continue;
        defer allocator.free(hash);
        try std.testing.expectEqual(@as(usize, 32), hash.len);
    }
}

test "BENCH: speed" {
    if (build_config.skip_heavy) return error.SkipZigTest;
    const allocator = std.testing.allocator;
    const data = try allocator.alloc(u8, 1 * 1024 * 1024); 
    defer allocator.free(data);
    std.crypto.random.bytes(data);

    var timer = try std.time.Timer.start();
    const hash = try basin.poseidonHash(data, allocator);
    defer allocator.free(hash);
    const ns = timer.read();

    const mb_s = 1.0 / (@as(f64, @floatFromInt(ns)) / 1e9);
    std.debug.print("\nbasin: {d:.2} MB/s\n", .{mb_s});
}
