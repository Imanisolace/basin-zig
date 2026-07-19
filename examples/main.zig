const std = @import("std");
const basin = @import("basin");

pub fn main()!void {
    const stdout = std.stdout.writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.print("=== Basin Zig v0.1.0 ===\n",.{});
    try stdout.print("High-Speed Poseidon Hashing\n\n",.{});

    // Init hasher
    var hasher = try basin.Hasher.init();
    defer hasher.deinit();

    // 1. Single hash demo
    const data = "basin benchmark data";
    const hash = try hasher.hash(data);
    const hex = try basin.toHex(hash, allocator);
    defer allocator.free(hex);
    try stdout.print("Input: {s}\n",.{data});
    try stdout.print("Single hash: {s}\n\n",.{hex});

    // 2. The flex: Parallel batch
    const N = 8000;
    const inputs = try allocator.alloc([]const u8, N); // CHANGED: var -> const
    defer allocator.free(inputs);
    for (inputs) |*i| i.* = data;

    try stdout.print("Running {d} hashes on 8 threads...\n",.{N});
    const start = std.time.milliTimestamp();

    const hashes = try hasher.hashBatch(inputs, allocator);
    defer {
        for (hashes) |h| allocator.free(h);
        allocator.free(hashes);
    }

    const elapsed = std.time.milliTimestamp() - start;
    const throughput = N * 1000 / @max(elapsed, 1);

    try stdout.print("Parallel 8 threads, {d} hashes: {d}ms\n",.{ N, elapsed });
    try stdout.print("Throughput: ~{d} hashes/sec\n",.{throughput});
    try stdout.print("\nSuccess! Basin is ready.\n",.{});
}