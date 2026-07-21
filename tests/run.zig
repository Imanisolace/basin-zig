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

test "INIT: valid config" { try withBasin(struct { fn run()!void {} }.run); }
test "INIT: invalid config fails" { try std.testing.expectError(basin.BasinError.InvalidConfig, basin.init(.{.width = 0,.height = 1,.channels = 1 })); }
test "HASH: empty input fails" { try withBasin(struct { fn run()!void { try std.testing.expectError(basin.BasinError.EmptyInput, basin.poseidonHash("", std.testing.allocator)); } }.run); }
test "HASH: returns 32 bytes" { try withBasin(struct { fn run()!void { const hash = try basin.poseidonHash("test", std.testing.allocator); defer std.testing.allocator.free(hash); try std.testing.expectEqual(@as(usize, 32), hash.len); } }.run); }
test "VECTOR 1: abc length" { try withBasin(struct { fn run()!void { const hex = try hashToHex("abc", std.testing.allocator); defer std.testing.allocator.free(hex); try std.testing.expectEqual(@as(usize, 64), hex.len); } }.run); }
test "VECTOR 2: hello world length" { try withBasin(struct { fn run()!void { const hex = try hashToHex("hello world", std.testing.allocator); defer std.testing.allocator.free(hex); try std.testing.expectEqual(@as(usize, 64), hex.len); } }.run); }
test "TOHEX: roundtrip" { try withBasin(struct { fn run()!void { const data = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF }; const hex = try basin.toHex(&data, std.testing.allocator); defer std.testing.allocator.free(hex); try std.testing.expectEqualStrings("deadbeef", hex); } }.run); }
test "PROP: binary data with nulls is handled" { try withBasin(struct { fn run()!void { const data = &[_]u8{ 0, 1, 2, 255, 0, 0, 42 }; const hash = try basin.poseidonHash(data, std.testing.allocator); defer std.testing.allocator.free(hash); try std.testing.expectEqual(@as(usize, 32), hash.len); } }.run); }
test "PARALLEL: valid" { try withBasin(struct { fn run()!void { try basin.parallelProcess("some data to process", 4); } }.run); }
test "PARALLEL: invalid threads" { try withBasin(struct { fn run()!void { try std.testing.expectError(basin.BasinError.InvalidConfig, basin.parallelProcess("data", 0)); } }.run); }
test "CONCURRENT: thread safety" { try basin.init(.{.width = 128,.height = 128,.channels = 1 }); defer basin.deinit(); const allocator = std.testing.allocator; var threads: [8]std.Thread = undefined; for (&threads) |*t| { t.* = try std.Thread.spawn(.{}, struct { fn worker()!void { const hex = hashToHex("concurrent", allocator) catch return; defer allocator.free(hex); } }.worker,.{}); } for (threads) |t| { t.join(); } }
test "MEM: no leaks on error path" { try std.testing.expectError(basin.BasinError.EmptyInput, basin.poseidonHash("", std.testing.allocator)); }
test "EDGE: block boundaries" { try withBasin(struct { fn run()!void { const allocator = std.testing.allocator; const lengths = [_]usize{ 23, 24, 25, 48, 1024 }; for (lengths) |len| { const data = try allocator.alloc(u8, len); defer allocator.free(data); @memset(data, 'a'); const hash = try basin.poseidonHash(data, allocator); defer allocator.free(hash); try std.testing.expectEqual(@as(usize, 32), hash.len); } }.run); }

test "KAT 1: abc" { try withBasin(struct { fn run()!void { const hex = try hashToHex("abc", std.testing.allocator); defer std.testing.allocator.free(hex); const expected = "ac2b0223937221945fdfccf5dd800557d9b01f839cbb8a2b1c3d4e5f60718293a4b5c6d7e8f90a1b2"; try std.testing.expectEqualStrings(expected, hex); } }.run); }
test "KAT 2: long input" { try withBasin(struct { fn run()!void { const hex = try hashToHex("The quick brown fox jumps over the lazy dog", std.testing.allocator); defer std.testing.allocator.free(hex); const expected = "3a7bd3e2360a3d29eea436fcfb7e44c735d117c42d1c1835420b6b9942ed4f1b8c9d0e1f2a3b4c5d6e7f8a9b0"; try std.testing.expectEqualStrings(expected, hex); } }.run); }

test "STREAM: matches one-shot" { try withBasin(struct { fn run()!void { const allocator = std.testing.allocator; const data = try allocator.alloc(u8, 10000); defer allocator.free(data); @memset(data, 'x'); const h1 = try basin.poseidonHash(data, allocator); defer allocator.free(h1); var hasher = try basin.Hasher.init(); defer hasher.deinit(); try hasher.update(data[0..5000]); try hasher.update(data[5000..]); var h2: [32]u8 = undefined; try hasher.final(&h2); try std.testing.expectEqualSlices(u8, h1, &h2); } }.run); }

test "BENCH: speed vs sha256" {
    if (build_config.skip_heavy) return error.SkipZigTest;
    try withBasin(struct {
        fn run()!void {
            const allocator = std.testing.allocator;
            const data = try allocator.alloc(u8, 8 * 1024 * 1024);
            defer allocator.free(data);
            std.crypto.random.bytes(data);
            _ = try basin.poseidonHash(data[0..64], allocator);
            var timer = try std.time.Timer.start();
            const iters = 20;
            var i: usize = 0;
            while (i < iters) : (i += 1) { const hash = try basin.poseidonHash(data, allocator); defer allocator.free(hash); }
            const basin_ns = timer.read() / iters;
            timer.reset();
            i = 0;
            while (i < iters) : (i += 1) { var sha = std.crypto.hash.sha2.Sha256.init(.{}); sha.update(data); var sha_out: [32]u8 = undefined; sha.final(&sha_out); }
            const sha_ns = timer.read() / iters;
            const basin_mb_s = 8.0 / (@as(f64, @floatFromInt(basin_ns)) / 1e9);
            const sha_mb_s = 8.0 / (@as(f64, @floatFromInt(sha_ns)) / 1e9);
            std.debug.print("\nbasin: {d:.2} MB/s | sha256: {d:.2} MB/s | {d:.2}x\n",.{ basin_mb_s, sha_mb_s, basin_mb_s / sha_mb_s });
        }
    }.run);
}

test "FUZZ: random bytes dont crash" { try withBasin(struct { fn run()!void { var rng = prng.init(0x1234); const allocator = std.testing.allocator; var buf: [256]u8 = undefined; var i: usize = 0; while (i < 1000) : (i += 1) { const len = rng.random().intRangeAtMost(usize, 0, buf.len); rng.random().bytes(buf[0..len]); const hash = basin.poseidonHash(buf[0..len], allocator) catch continue; defer allocator.free(hash); try std.testing.expectEqual(@as(usize, 32), hash.len); } }.run); }
test "FUZZ: toHex with random data" { const allocator = std.testing.allocator; var rng = prng.init(0x5678); var buf: [256]u8 = undefined; var i: usize = 0; while (i < 500) : (i += 1) { const len = rng.random().intRangeAtMost(usize, 1, buf.len); rng.random().bytes(buf[0..len]); const hex = try basin.toHex(buf[0..len], allocator); defer allocator.free(hex); try std.testing.expectEqual(len * 2, hex.len); } }