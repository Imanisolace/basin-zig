const std = @import("std");
const basin = @import("basin");

fn hashToHex(input: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const hash_bytes = try basin.poseidonHash(input, allocator);
    defer allocator.free(hash_bytes);
    return try basin.toHex(hash_bytes, allocator);
}

fn withBasin(comptime f: fn() anyerror!void) !void {
    try basin.init(.{ .width = 3, .height = 1, .channels = 1 });
    defer basin.deinit();
    try f();
}

test "VECTOR 2: abc" {
    try withBasin(struct{
        fn run() !void {
            const hex = try hashToHex("abc", std.testing.allocator);
            defer std.testing.allocator.free(hex);
            try std.testing.expectEqualStrings("126004b8006452630ea03001973ac600", hex);
        }
    }.run);
}

test "VECTOR 3: hello world" {
    try withBasin(struct{
        fn run() !void {
            const hex = try hashToHex("hello world", std.testing.allocator);
            defer std.testing.allocator.free(hex);
            try std.testing.expectEqualStrings("0e4f1b195d62956fb3a57aa2154e5b01", hex);
        }
    }.run);
}

test "PROP: deterministic" {
    try withBasin(struct{
        fn run() !void {
            const h1 = try hashToHex("deterministic", std.testing.allocator);
            defer std.testing.allocator.free(h1);
            const h2 = try hashToHex("deterministic", std.testing.allocator);
            defer std.testing.allocator.free(h2);
            try std.testing.expectEqualStrings(h1, h2);
        }
    }.run);
}

test "PROP: any input -> 32 hex chars" {
    try withBasin(struct{
        fn run() !void {
            const inputs = [_][]const u8{ "a", "hello", "\x00\xff", "a" ** 1000 };
            for (inputs) |input| {
                const hex = try hashToHex(input, std.testing.allocator);
                defer std.testing.allocator.free(hex);
                try std.testing.expect(hex.len == 32);
            }
        }
    }.run);
}

test "PROP: 1 bit flip changes hash" {
    try withBasin(struct{
        fn run() !void {
            const h1 = try hashToHex("data", std.testing.allocator);
            defer std.testing.allocator.free(h1);
            const h2 = try hashToHex("dara", std.testing.allocator); // 1 char diff
            defer std.testing.allocator.free(h2);
            try std.testing.expect(!std.mem.eql(u8, h1, h2));
        }
    }.run);
}

test "Smoke: non-empty input works" {
    try withBasin(struct{
        fn run() !void {
            const hex = try hashToHex("x", std.testing.allocator);
            defer std.testing.allocator.free(hex);
            try std.testing.expect(hex.len == 32);
        }
    }.run);
}

test "STRESS: parallelProcess is thread-safe" {
    try withBasin(struct{
        fn run() !void {
            const Thread = std.Thread;
            const thread_count = 16;
            var threads: [thread_count]Thread = undefined;
            for (&threads) |*t| {
                t.* = try Thread.spawn(.{}, worker, .{50});
            }
            for (threads) |t| t.join();
        }
        fn worker(iterations: usize) !void {
            var i: usize = 0;
            while (i < iterations) : (i += 1) {
                try basin.parallelProcess("stress test data", 4);
            }
        }
    }.run);
}

test "PROP: empty input works" {
    try withBasin(struct{
        fn run() !void {
            const hex = try hashToHex("", std.testing.allocator);
            defer std.testing.allocator.free(hex);
            try std.testing.expect(hex.len == 32);
        }
    }.run);
}

test "PROP: large input does not overflow" {
    try withBasin(struct{
        fn run() !void {
            const big = try std.testing.allocator.alloc(u8, 1024 * 1024);
            defer std.testing.allocator.free(big);
            @memset(big, 'A');
            
            const hex = try hashToHex(big, std.testing.allocator);
            defer std.testing.allocator.free(hex);
            try std.testing.expect(hex.len == 32);
        }
    }.run);
}

test "PROP: allocator failure is handled" {
    try withBasin(struct{
        fn run() !void {
            var fail = std.testing.FailingAllocator.init(std.testing.allocator, 0);
            const result = hashToHex("test", fail.allocator());
            try std.testing.expectError(error.OutOfMemory, result);
        }
    }.run);
}