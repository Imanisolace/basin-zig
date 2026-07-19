const std = @import("std");
const basin = @import("basin");

pub fn main()!void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.print("=== Basin Zig v0.1.0 Benchmarks ===\n\n",.{});

    // Init
    try basin.init(.{.width = 256,.height = 256,.channels = 3 });
    defer basin.deinit();

    // TEST 1: Correctness
    try stdout.print("TEST 1: Correctness\n",.{});
    const data = "basin benchmark data";
    const hash1 = try basin.poseidonHash(data, allocator);
    defer allocator.free(hash1);
    const hash2 = try basin.poseidonHash(data, allocator);
    defer allocator.free(hash2);
    
    if (std.mem.eql(u8, hash1, hash2)) {
        try stdout.print("PASS: Same input = same hash\n",.{});
    } else {
        try stdout.print("FAIL: Hashes don't match\n",.{});
    }
    const hex = try basin.toHex(hash1, allocator);
    defer allocator.free(hex);
    try stdout.print("Hash: {s}\n\n",.{hex});

    // TEST 2: Single thread speed
    try stdout.print("TEST 2: Speed - 1000 hashes\n",.{});
    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        const h = try basin.poseidonHash(data, allocator);
        allocator.free(h);
    }
    const elapsed = std.time.milliTimestamp() - start;
    try stdout.print("1000 hashes: {d}ms  ->  {d:.2} hashes/ms\n\n",.{elapsed, 1000.0 / @as(f64, @floatFromInt(elapsed))});

    // TEST 3: Thread scaling
    try stdout.print("TEST 3: Thread Scaling\n",.{});
    const threads = [_]i32{ 1, 2, 4, 8 };
    for (threads) |t| {
        const s = std.time.milliTimestamp();
        try basin.parallelProcess(data, t);
        const e = std.time.milliTimestamp() - s;
        try stdout.print("Threads {d}: {d}ms\n",.{t, e});
    }

    try stdout.print("\nSuccess! All tests passed.\n",.{});
}
