const std = @import("std");
const basin = @import("basin");

const Config = struct {
    data: []const u8,
    threads: i32 = 1,
    bench: bool = false,
};

fn isCI(allocator: std.mem.Allocator) bool {
    const ci = std.process.getEnvVarOwned(allocator, "GITHUB_ACTIONS") catch return false;
    defer allocator.free(ci);
    return std.mem.eql(u8, ci, "true");
}

fn log(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) void {
    if (isCI(allocator)) return; // Skip printing in CI to avoid.FAULT crash
    const stderr = std.io.getStdErr().writer();
    stderr.print(fmt, args) catch {};
}

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
            cfg.data = arg;
        }
    }
    return cfg;
}

pub fn main()!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const cfg = parseArgs(allocator) catch |err| {
        log(allocator, "Usage: basin-example [data] [--bench] [--threads N]\n",.{});
        return err;
    };

    log(allocator, "=== Basin Zig v0.1.1 ===\n",.{});
    log(allocator, "Input: '{s}'\n",.{cfg.data});

    const basin_cfg = if (cfg.bench)
        basin.BasinConfig{.width = 256,.height = 256,.channels = 3 }
    else
        basin.BasinConfig{.width = 3,.height = 1,.channels = 1 };

    try basin.init(basin_cfg);
    defer basin.deinit();

    const hash_bytes = try basin.poseidonHash(cfg.data, allocator);
    defer allocator.free(hash_bytes);
    const hex = try basin.toHex(hash_bytes, allocator);
    defer allocator.free(hex);
    log(allocator, "Hash: {s}\n\n",.{hex});

    if (cfg.bench) {
        log(allocator, "--- Speed: 100 hashes ---\n",.{});
        const start = std.time.milliTimestamp();
        var i: usize = 0;
        while (i < 100) : (i += 1) {
            const h = try basin.poseidonHash(cfg.data, allocator);
            allocator.free(h);
        }
        const elapsed = std.time.milliTimestamp() - start;
        const rate: f64 = if (elapsed > 0) 100.0 / @as(f64, @floatFromInt(elapsed)) else 0;
        log(allocator, "{d}ms -> {d:.2} hashes/ms\n",.{ elapsed, rate });

        log(allocator, "--- Thread Scaling ---\n",.{});
        const thread_list = [_]i32{ 1, 2, 4 };
        for (thread_list) |t| {
            const s = std.time.milliTimestamp();
            try basin.parallelProcess(cfg.data, t);
            const e = std.time.milliTimestamp() - s;
            log(allocator, "Threads {d}: {d}ms\n",.{ t, e });
        }
    }

    if (cfg.threads > 1 and !cfg.bench) {
        log(allocator, "--- Parallel Process ---\n",.{});
        const s = std.time.milliTimestamp();
        try basin.parallelProcess(cfg.data, cfg.threads);
        const e = std.time.milliTimestamp() - s;
        log(allocator, "Threads {d}: {d}ms\n",.{ cfg.threads, e });
    }
}