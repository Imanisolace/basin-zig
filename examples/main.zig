const std = @import("std");
const basin = @import("basin");

const Config = struct {
    data: []const u8,
    bench: bool = false,
    is_allocated: bool = false,
};

fn parseArgs(allocator: std.mem.Allocator)!Config {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var cfg = Config{
       .data = "basin benchmark data",
       .bench = false,
       .is_allocated = false,
    };

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--bench")) {
            cfg.bench = true;
        } else {
            // FIX: dupe so it survives argsFree
            cfg.data = try allocator.dupe(u8, arg);
            cfg.is_allocated = true;
        }
    }
    return cfg;
}

pub fn main()!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const stderr = std.io.getStdErr().writer();

    // FIX: Cache CI flag once. No allocs in hot path
    const is_ci = ci_block: {
        const ci = std.process.getEnvVarOwned(allocator, "GITHUB_ACTIONS") catch |err| {
            if (err == error.EnvironmentVariableNotFound) break :ci_block false;
            return err;
        };
        defer allocator.free(ci);
        break :ci_block std.mem.eql(u8, ci, "true");
    };

    var cfg = parseArgs(allocator) catch {
        if (!is_ci) _ = stderr.write("Usage: basin-example [data] [--bench]\n") catch {};
        return;
    };
    defer if (cfg.is_allocated) allocator.free(cfg.data);

    if (!is_ci) {
        try stderr.print("=== Basin Zig v0.1.0 ===\n",.{});
        try stderr.print("Input: '{s}'\n",.{cfg.data});
    }

    // One-shot API call
    const hash_bytes = try basin.poseidonHash(cfg.data, allocator);
    defer allocator.free(hash_bytes);
    const hex = try basin.toHex(hash_bytes, allocator);
    defer allocator.free(hex);
    if (!is_ci) try stderr.print("Hash: {s}\n\n",.{hex});

    // FIX: Bench the core, not the allocator
    if (cfg.bench) {
        if (!is_ci) try stderr.print("--- Speed: 10,000 hashes (Stack Only) ---\n",.{});

        var buf: [basin.OUTPUT_SIZE]u8 = undefined;
        const start = std.time.milliTimestamp();

        var i: usize = 0;
        while (i < 10000) : (i += 1) {
            var h = basin.Hasher.init();
            h.update(cfg.data);
            h.final(&buf);
        }

        const elapsed = std.time.milliTimestamp() - start;
        if (!is_ci) {
            const rate: f64 = if (elapsed > 0) 10000.0 / @as(f64, @floatFromInt(elapsed)) else 0;
            try stderr.print("{d}ms -> {d:.2} hashes/ms\n",.{ elapsed, rate });
        }
    }
}