const std = @import("std");
const basin = @import("basin");

pub fn main()!void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.print("=== Basin Zig v0.1.0 ===\n",.{});
    try stdout.print("High-Speed Poseidon Hashing\n",.{});

    // Init with config - match your C API
    try basin.init(.{.width = 256,.height = 256,.channels = 3 });
    defer basin.deinit();

    const data = "basin benchmark data";

    // Single hash
    const hash = try basin.poseidonHash(data, allocator);
    defer allocator.free(hash);
    const hex = try basin.toHex(hash, allocator);
    defer allocator.free(hex);

    try stdout.print("Input: {s}\n",.{data});
    try stdout.print("Single hash: {s}\n\n",.{hex});

    // Parallel test
    try stdout.print("Running parallel test with 8 threads...\n",.{});
    const start = std.time.milliTimestamp();
    try basin.parallelProcess(data, 8);
    const elapsed = std.time.milliTimestamp() - start;

    try stdout.print("Parallel 8 threads: {d}ms\n",.{elapsed});
    try stdout.print("\nSuccess! Basin is ready.\n",.{});
}
