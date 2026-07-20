const std = @import("std");
const basin = @import("basin");

const Config = struct {
    data: []const u8,
    threads: i32 = 1,
    bench: bool = false,
};

fn parseArgs(allocator: std.mem.Allocator)!Config {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var cfg = Config{.data = "basin benchmark data" };

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--bench")) {
            cfg.bench = true;
        } else if (std.mem.eql(u8, arg, "--threads")) {
            i += 1;
            if (i >= args.len) return error.MissingThreadsValue;
            cfg.threads = try std.fmt.parseInt(i32, args[i], 10);
        } else {
            cfg.data = arg; // first non-flag arg = input data
        }
    }
    return cfg;
}

pub fn main()!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const cfg = parseArgs(allocator) catch |err| {
        std.debug.print("Usage: basin-example [data] [--bench] [--threads N]\n",.{});
        return err;
    };

    // Buffered stdout so CI doesn't panic on pipe close
    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();
    defer bw.flush() catch {};

    stdout.print("=== Basin Zig v0.1.1 ===\n",.{}) catch {};
    stdout.print("Input: '{s}'\n",.{cfg.data}) catch {};

    // Pick config: big for bench, small for single hash
    const basin_cfg = if (cfg.bench)
        basin.BasinConfig{.width = 256,.height = 256,.channels = 3 }
    else
        basin.BasinConfig{.width = 3,.height = 1,.channels = 1 };

    basin.init(basin_cfg) catch {};
    defer basin.deinit();

    // Single hash
    const hash_bytes = basin.poseidonHash(cfg.data, allocator) catch return;
    defer allocator.free(hash_bytes);
    const hex = basin.toHex(hash_bytes, allocator) catch return;
    defer allocator.free(hex);
    stdout.print("Hash: {s}\n\n",.{hex}) catch {};

    // Benchmarks
    if (cfg.bench) {
        stdout.print("--- Speed: 100 hashes ---\n",.{}) catch {};
        const start = std.time.milliTimestamp();
        var i: usize = 0;
        while (i < 100) : (i += 1) {
            const h = basin.poseidonHash(cfg.data, allocator) catch continue;
            allocator.free(h);
        }
        const elapsed = std.time.milliTimestamp() - start;
        const rate: f64 = if (elapsed > 0) 100.0 / @as(f64, @floatFromInt(elapsed)) else 0;
        stdout.print("{d}ms -> {d:.2} hashes/ms\n",.{elapsed, rate}) catch {};

        // Thread scaling - reduced for CI
        stdout.print("--- Thread Scaling ---\n",.{}) catch {};
        const thread_list = [_]i32{ 1, 2, 4 };
        for (thread_list) |t| {
            const s = std.time.milliTimestamp();
            basin.parallelProcess(cfg.data, t) catch {};
            const e = std.time.milliTimestamp() - s;
            stdout.print("Threads {d}: {d}ms\n",.{t, e}) catch {};
        }
    }

    // Single parallel run
    if (cfg.threads > 1 and!cfg.bench) {
        stdout.print("--- Parallel Process ---\n",.{}) catch {};
        const s = std.time.milliTimestamp();
        basin.parallelProcess(cfg.data, cfg.threads) catch {};
        const e = std.time.milliTimestamp() - s;
        stdout.print("Threads {d}: {d}ms\n",.{cfg.threads, e}) catch {};
    }
}