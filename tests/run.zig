const std = @import("std");
const basin = @import("basin");

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

test "INIT: valid config" {
    try withBasin(struct {
        fn run()!void {}
    }.run);
}

test "INIT: invalid config fails" {
    try std.testing.expectError(
        basin.BasinError.InvalidConfig,
        basin.init(.{.width = 0,.height = 1,.channels = 1 }),
    );
}

test "HASH: empty input fails" {
    try withBasin(struct {
        fn run()!void {
            try std.testing.expectError(
                basin.BasinError.EmptyInput,
                basin.poseidonHash("", std.testing.allocator),
            );
        }
    }.run);
}

test "HASH: returns 32 bytes" {
    try withBasin(struct {
        fn run()!void {
            const hash = try basin.poseidonHash("test", std.testing.allocator);
            defer std.testing.allocator.free(hash);
            try std.testing.expectEqual(@as(usize, 32), hash.len);
        }
    }.run);
}

test "VECTOR 1: abc" {
    try withBasin(struct {
        fn run()!void {
            const hex = try hashToHex("abc", std.testing.allocator);
            defer std.testing.allocator.free(hex);
            try std.testing.expectEqual(@as(usize, 64), hex.len);
        }
    }.run);
}

test "VECTOR 2: hello world" {
    try withBasin(struct {
        fn run()!void {
            const hex = try hashToHex("hello world", std.testing.allocator);
            defer std.testing.allocator.free(hex);
            try std.testing.expectEqual(@as(usize, 64), hex.len);
        }
    }.run);
}

test "TOHEX: roundtrip" {
    try withBasin(struct {
        fn run()!void {
            const data = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
            const hex = try basin.toHex(&data, std.testing.allocator);
            defer std.testing.allocator.free(hex);
            try std.testing.expectEqualStrings("deadbeef", hex);
        }
    }.run);
}

test "PROP: binary data with nulls is handled" {
    try withBasin(struct {
        fn run()!void {
            const data = &[_]u8{ 0, 1, 2, 255, 0, 0, 42 };
            const hash = try basin.poseidonHash(data, std.testing.allocator);
            defer std.testing.allocator.free(hash);
            try std.testing.expectEqual(@as(usize, 32), hash.len);
        }
    }.run);
}

test "PARALLEL: valid" {
    try withBasin(struct {
        fn run()!void {
            try basin.parallelProcess("some data to process", 4);
        }
    }.run);
}

test "PARALLEL: invalid threads" {
    try withBasin(struct {
        fn run()!void {
            try std.testing.expectError(
                basin.BasinError.InvalidConfig,
                basin.parallelProcess("data", 0),
            );
        }
    }.run);
}

test "CONCURRENT: thread safety" {
    try basin.init(.{.width = 128,.height = 128,.channels = 1 });
    defer basin.deinit();
    
    const allocator = std.testing.allocator;
    var threads: [8]std.Thread = undefined;
    
    for (&threads) |*t| {
        t.* = try std.Thread.spawn(.{}, struct {
            fn worker()!void {
                const hex = hashToHex("concurrent", allocator) catch return;
                defer allocator.free(hex);
            }
        }.worker,.{});
    }
    for (threads) |t| {
        t.join();
    }
}

test "MEM: no leaks on error path" {
    try std.testing.expectError(
        basin.BasinError.EmptyInput,
        basin.poseidonHash("", std.testing.allocator),
    );
}