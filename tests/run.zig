const std = @import("std");
const basin = @import("basin");
const BasinError = basin.BasinError;

fn hashToHex(input: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const hash_bytes = try basin.poseidonHash(input, allocator);
    defer allocator.free(hash_bytes);
    
    const hex = try allocator.alloc(u8, hash_bytes.len * 2);
    _ = std.fmt.bufPrint(hex, "{s}", .{std.fmt.fmtSliceHexLower(hash_bytes)}) catch unreachable;
    return hex;
}

fn withBasin(comptime f: fn() anyerror!void) !void {
    try basin.init(.{ .width = 3, .height = 1, .channels = 1 });
    defer basin.deinit();
    try f();
}

test "VECTOR 1: abc" {
    try withBasin(struct{ fn run() !void {
        const hex = try hashToHex("abc", std.testing.allocator);
        defer std.testing.allocator.free(hex);
        try std.testing.expectEqualStrings("126004b8006452630ea03001973ac600", hex);
    }}.run);
}

test "VECTOR 2: hello world" {
    try withBasin(struct{ fn run() !void {
        const hex = try hashToHex("hello world", std.testing.allocator);
        defer std.testing.allocator.free(hex);
        try std.testing.expectEqualStrings("0e4f1b195d62956fb3a57aa2154e5b01", hex);
    }}.run);
}

test "PROP: deterministic" {
    try withBasin(struct{ fn run() !void {
        const h1 = try hashToHex("deterministic", std.testing.allocator);
        defer std.testing.allocator.free(h1);
        const h2 = try hashToHex("deterministic", std.testing.allocator);
        defer std.testing.allocator.free(h2);
        try std.testing.expectEqualStrings(h1, h2);
    }}.run);
}

test "PROP: any input -> 32 hex chars" {
    try withBasin(struct{ fn run() !void {
        const null_bytes = &[_]u8{0, 0xff};
        const inputs = [_][]const u8{ "a", "hello", null_bytes, "a" ** 1000 };
        for (inputs) |input| {
            const hex = try hashToHex(input, std.testing.allocator);
            defer std.testing.allocator.free(hex);
            try std.testing.expect(hex.len == 32);
        }
    }}.run);
}

test "PROP: 1 bit flip changes hash" {
    try withBasin(struct{ fn run() !void {
        const h1 = try hashToHex("data", std.testing.allocator);
        defer std.testing.allocator.free(h1);
        const h2 = try hashToHex("dara", std.testing.allocator);
        defer std.testing.allocator.free(h2);
        try std.testing.expect(!std.mem.eql(u8, h1, h2));
    }}.run);
}

test "Smoke: non-empty input works" {
    try withBasin(struct{ fn run() !void {
        const hex = try hashToHex("x", std.testing.allocator);
        defer std.testing.allocator.free(hex);
        try std.testing.expect(hex.len == 32);
    }}.run);
}

test "STRESS: parallelProcess is thread-safe" {
    try withBasin(struct{ fn run() !void {
        const Thread = std.Thread;
        const thread_count = 16;
        var threads: [thread_count]Thread = undefined;
        for (&threads) |*t| t.* = try Thread.spawn(.{}, worker, .{50});
        for (threads) |t| t.join();
    }
    fn worker(iterations: usize) !void {
        var i: usize = 0;
        while (i < iterations) : (i += 1) try basin.parallelProcess("stress test data", 4);
    }}.run);
}

test "PROP: empty input returns error" {
    try withBasin(struct{ fn run() !void {
        const result = hashToHex("", std.testing.allocator);
        try std.testing.expectError(BasinError.EmptyInput, result);
    }}.run);
}

test "PROP: large input does not overflow" {
    try withBasin(struct{ fn run() !void {
        const big = try std.testing.allocator.alloc(u8, 1024 * 1024);
        defer std.testing.allocator.free(big);
        @memset(big, 'A');
        const hex = try hashToHex(big, std.testing.allocator);
        defer std.testing.allocator.free(hex);
        try std.testing.expect(hex.len == 32);
    }}.run);
}

test "PROP: different init configs give different hashes" {
    try basin.init(.{ .width = 3, .height = 1, .channels = 1 });
    defer basin.deinit();
    const h1 = try hashToHex("seed", std.testing.allocator);
    defer std.testing.allocator.free(h1);

    try basin.init(.{ .width = 5, .height = 1, .channels = 1 });
    defer basin.deinit();
    const h2 = try hashToHex("seed", std.testing.allocator);
    defer std.testing.allocator.free(h2);

    try std.testing.expect(!std.mem.eql(u8, h1, h2));
}

test "PROP: concurrent init/deinit is safe" {
    const Thread = std.Thread;
    const thread_count = 8;
    var threads: [thread_count]Thread = undefined;
    for (&threads) |*t| {
        t.* = try Thread.spawn(.{}, concurrentWorker, .{20});
    }
    for (threads) |t| t.join();
}
fn concurrentWorker(iterations: usize) !void {
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        basin.init(.{ .width = 3, .height = 1, .channels = 1 }) catch continue;
        defer basin.deinit();
        _ = hashToHex("concurrent", std.testing.allocator) catch continue;
    }
}

test "PROP: binary data with nulls is handled" {
    try withBasin(struct{ fn run() !void {
        const bin = &[_]u8{ 0, 1, 2, 255, 0, 0, 127 };
        const hex = try hashToHex(bin, std.testing.allocator);
        defer std.testing.allocator.free(hex);
        try std.testing.expect(hex.len == 32);
    }}.run);
}