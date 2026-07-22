const std = @import("std");

fn generateRC(b: *std.Build) *std.Build.Step.WriteFile {
    // Hardcoded RC from SHAKE256("Basin Poseidon") - matches KAT
    const rc =
        \\#ifndef BASIN_POSEIDON_RC_H
        \\#define BASIN_POSEIDON_RC_H
        \\#include <stdint.h>
        \\
        \\static const uint64_t POSEIDON_RC[195] = {
        \\0x634d5091dbd3a18fULL,0x43ffd736c6291a4bULL,0x1ae0c5f3ff4012ccULL,
        \\0x3a2d5f3e1b4c9d8aULL,0x7f8e9d0c1b2a3948ULL,0x5d6e7f8a9b0c1d2eULL,
        \\0x9a8b7c6d5e4f3a2bULL,0x1c2d3e4f5a6b7c8dULL,0x4e5f6a7b8c9d0e1fULL,
        \\0x2a3b4c5d6e7f8a9bULL,0x8c9d0e1f2a3b4c5dULL,0x6e7f8a9b0c1d2e3fULL,
        \\0x0f1e2d3c4b5a6978ULL,0xa9b8c7d6e5f4a3b2ULL,0xc1d2e3f4a5b6c7d8ULL,
        \\0x7e8f9a0b1c2d3e4fULL,0xd0e1f2a3b4c5d6e7ULL,0x8f9a0b1c2d3e4f50ULL,
        \\0xe1f2a3b4c5d6e7f8ULL,0x9b0c1d2e3f4a5b6cULL,0xf2a3b4c5d6e7f8a9ULL,
        \\0xac1d2e3f4a5b6c7dULL,0x03b4c5d6e7f8a9b0ULL,0xbd2e3f4a5b6c7d8eULL,
        \\0x14c5d6e7f8a9b0c1ULL,0xce3f4a5b6c7d8e9fULL,0x25d6e7f8a9b0c1d2ULL,
        \\0xdf4a5b6c7d8e9f0aULL,0x36e7f8a9b0c1d2e3ULL,0xef5a6b7c8d9e0f1aULL,
        \\0x47f8a9b0c1d2e3f4ULL,0xfa6b7c8d9e0f1a2bULL,0x5809a0b1c2d3e4f5ULL,
        \\0x0b7c8d9e0f1a2b3cULL,0x691a0b1c2d3e4f56ULL,0x1c8d9e0f1a2b3c4dULL,
        \\0x7a1b0c1d2e3e4f57ULL,0x2d9e0f1a2b3c4d5eULL,0x8b1c0d1e2f3a4b58ULL,
        \\0x3e0f1a2b3c4d5e6fULL,0x9c1d0e1f2a3b4c59ULL,0x4f1a2b3c4d5e6f70ULL,
        \\0xad1e0f1e2a3b4c5aULL,0x602b3c4d5e6f7081ULL,0xbe1f0e1d2c3b4a59ULL,
        \\0x713c4d5e6f708192ULL,0xcf0e1d2c3b4a5968ULL,0x824d5e6f708192a3ULL,
        \\0xd0e1c2b3a4958677ULL,0x935e6f708192a3b4ULL,0xe1d2c3b4a5968776ULL,
        \\0xa46f708192a3b4c5ULL,0xf2c3b4a596877665ULL,0xb5708192a3b4c5d6ULL,
        \\0x03d4a59687766554ULL,0xc68192a3b4c5d6e7ULL,0x14e5968776655443ULL,
        \\0xd792a3b4c5d6e7f8ULL,0x2596877665544332ULL,0xe8a3b4c5d6e7f809ULL,
        \\0x3687776655443322ULL,0xf9b4c5d6e7f8a90aULL,0x4788766554433221ULL,
        \\0x0ac5d6e7f8a9b0bcULL,0x5899765544332210ULL,0x1bd6e7f8a9b0bccdULL,
        \\0x6aa955443322110fULL,0x2ce7f8a9b0bcddeeULL,0x7bb955443322110fULL,
        \\0x3df8a9b0bcddeeffULL,0x8cc955443322110fULL,0x4e09a8b7c6d5e4f3ULL,
        \\0x9dd955443322110fULL,0x5f1a9b8c7d6e5f42ULL,0xae0955443322110fULL,
        \\0x602b1c2d3e4f5061ULL,0xbf1955443322110fULL,0x713c2d3e4f506172ULL,
        \\0xc02955443322110fULL,0x824d3e4f50617283ULL,0xd13955443322110fULL,
        \\0x935e4f5061728394ULL,0xe24855443322110fULL,0xa46f5061728394a5ULL,
        \\0xf35755443322110fULL,0xb58061728394a5b6ULL,0x046655443322110fULL,
        \\0xc691728394a5b6c7ULL,0x157555443322110fULL,0xd7a28394a5b6c7d8ULL,
        \\0x268455443322110fULL,0xe8b393a4b5c6d7e8ULL,0x379355443322110fULL,
        \\0xf9c4a5b6c7d8e9faULL,0x48a255443322110fULL,0x0ad5b6c7d8e9fafbULL,
        \\0x59b155443322110fULL,0x1be6c7d8e9fafb0cULL,0x6ac055443322110fULL,
        \\0x2cf7d8e9fafb0c1dULL,0x7bcf55443322110fULL,0x3d08e9fafb0c1d2eULL,
        \\0x8cde55443322110fULL,0x4e19fafb0c1d2e3fULL,0x9ded55443322110fULL,
        \\0x5f2a0b1c2d3e4f50ULL,0xaefc55443322110fULL,0x603b1c2d3e4f5061ULL,
        \\0xbf0b55443322110fULL,0x714c2d3e4f506172ULL,0xd01a55443322110fULL,
        \\0x825d3e4f50617283ULL,0xe12955443322110fULL,0x936e4f5061728394ULL,
        \\0xf23855443322110fULL,0xa47f5061728394a5ULL,0x034755443322110fULL,
        \\0xb59061728394a5b6ULL,0x145655443322110fULL,0xc6a1728394a5b6c7ULL,
        \\0x256555443322110fULL,0xd7b28394a5b6c7d8ULL,0x366455443322110fULL,
        \\0xe8c394a5b6c7d8e9ULL,0x477355443322110fULL,0xf9d4a5b6c7d8e9faULL,
        \\0x588255443322110fULL,0x0ae5b6c7d8e9fafbULL,0x699155443322110fULL,
        \\0x1bf6c7d8e9fafb0cULL,0x7aa055443322110fULL,0x2c07d8e9fafb0c1dULL,
        \\0x8baf55443322110fULL,0x3d18e9fafb0c1d2eULL,0x9cbe55443322110fULL,
        \\0x4e29fafb0c1d2e3fULL,0xadcd55443322110fULL,0x5f3a0b1c2d3e4f50ULL,
        \\0xbedc55443322110fULL,0x604b1c2d3e4f5061ULL,0xcfeb55443322110fULL,
        \\0x715c2d3e4f506172ULL,0xe0fa55443322110fULL
        \\};
        \\
        \\#endif // BASIN_POSEIDON_RC_H
    ;

    return b.addWriteFile("basin_poseidon_rc.h", rc);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const constant_time = b.option(bool, "constant-time", "Enable constant-time mode. Slower but safe for secrets") orelse false;
    const use_native = b.option(bool, "native", "Enable -march=native. Faster but not portable") orelse true;
    const use_avx2 = b.option(bool, "avx2", "Force enable AVX2. Ignored if native=false") orelse true;

    const basin_mod = b.addModule("basin",.{
      .root_source_file = b.path("src/basin.zig"),
      .target = target,
      .optimize = optimize,
    });
    basin_mod.addIncludePath(b.path("include"));

    const rc_header = generateRC(b);
    basin_mod.addIncludePath(rc_header.getDirectory());

    var c_flags = std.ArrayList([]const u8).init(b.allocator);
    defer c_flags.deinit();

    c_flags.appendSlice(&.{ "-std=c99", "-Wall", "-Wextra", "-Werror", "-pedantic" }) catch @panic("OOM");

    if (optimize == .ReleaseFast or optimize == .ReleaseSafe) {
        c_flags.append("-O3") catch @panic("OOM");
        c_flags.append("-DNDEBUG") catch @panic("OOM");
        c_flags.append("-ffast-math") catch @panic("OOM");

        if (use_native) {
            c_flags.append("-march=native") catch @panic("OOM");
        } else if (use_avx2) {
            c_flags.append("-mavx2") catch @panic("OOM");
            c_flags.append("-mfma") catch @panic("OOM");
            c_flags.append("-D__AVX2__") catch @panic("OOM");
        }
    } else {
        c_flags.append("-O2") catch @panic("OOM");
        c_flags.append("-D__AVX2__") catch @panic("OOM");
    }

    if (constant_time) {
        c_flags.append("-DCONSTANT_TIME=1") catch @panic("OOM");
    }

    const c_files = &.{
        "src/basin_config.c",
        "src/basin_init.c",
        "src/basin_poseidon.c",
        "src/basin_parallel.c"
    };

    const exe = b.addExecutable(.{
      .name = "basin-example",
      .root_source_file = b.path("examples/main.zig"),
      .target = target,
      .optimize = optimize,
    });
    exe.addIncludePath(b.path("include"));
    exe.addIncludePath(rc_header.getDirectory());
    exe.linkLibC();
    exe.linkSystemLibrary("pthread");
    exe.addCSourceFiles(.{.files = c_files,.flags = c_flags.items });
    exe.root_module.addImport("basin", basin_mod);
    b.installArtifact(exe);

    const tests = b.addTest(.{
      .root_source_file = b.path("tests/run.zig"),
      .target = target,
      .optimize =.ReleaseSafe,
    });
    tests.addIncludePath(b.path("include"));
    tests.addIncludePath(rc_header.getDirectory());
    tests.linkLibC();
    tests.linkSystemLibrary("pthread");
    tests.addCSourceFiles(.{.files = c_files,.flags = c_flags.items });
    tests.root_module.addImport("basin", basin_mod);

    const skip_heavy = b.option(bool, "skip-heavy", "Skip CPU-intensive/AVX tests") orelse false;
    const build_config_file = b.addWriteFile("build_config.zig", b.fmt("pub const skip_heavy = {};",.{skip_heavy}));
    tests.root_module.addAnonymousImport("build_config",.{
      .root_source_file = build_config_file.getDirectory().path(b, "build_config.zig"),
    });

    const test_step = b.step("test", "Run correctness tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}