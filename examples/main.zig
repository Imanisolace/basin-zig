const std = @import("std");
const basin = @import("basin");

const Config = struct {
    data: []const u8,
    bench: bool = false,
};

fn isCI(allocator: std.mem.Allocator) bool {
    const ci = std.process.getEnvVarOwned(allocator, "GITHUB_ACTIONS") catch return false;
    defer allocator.free(ci);
    return std.mem.eql(u8, ci, "true");
}

fn log(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) void {
    if (isCI(allocator)) return; // Skip printing in CI to avoid FAULT crash
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
        log(allocator, "Usage: basin-example [data] [--bench]\n",.{});
        return err;
    };

    log(allocator, "=== Basin Zig v0.1.0 ===\n",.{});
    log(allocator, "Input: '{s}'\n",.{cfg.data});

    // Pure v0.1: No init, no config, no threads. Just hash
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
    }
}