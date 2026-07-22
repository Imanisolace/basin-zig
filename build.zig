const std = @import("std");

fn generateRC(b: *std.Build) *std.Build.Step.WriteFile {
    // RC[i] = SHAKE256("Basin Poseidon" || BE(u64(i)), 8 bytes)
    var rc: [195]u64 = undefined;
    for (0..195) |i| {
        var input: [22]u8 = undefined;
        @memcpy(input[0..14], "Basin Poseidon");
        std.mem.writeInt(u64, input[14..22], @as(u64,i),.big); // BE not LE

        var shake = std.crypto.hash.sha3.Shake256.init(.{});
        shake.update(&input);
        var out: [8]u8 = undefined;
        shake.final(&out);

        rc[i] = std.mem.readInt(u64, &out,.little); // but read result as LE
    }

    var buf = std.ArrayList(u8).init(b.allocator);
    defer buf.deinit();
    const w = buf.writer();

    w.print("#ifndef BASIN_POSEIDON_RC_H\n#define BASIN_POSEIDON_RC_H\n#include <stdint.h>\n\nstatic const uint64_t POSEIDON_RC[195] = {{\n",.{}) catch @panic("OOM");
    for (rc, 0..) |v, i| {
        w.print("0x{x:0>16}ULL",.{v}) catch @panic("OOM");
        if (i != rc.len - 1) w.print(",",.{}) catch @panic("OOM");
        if (i % 3 == 2) w.print("\n",.{}) catch @panic("OOM");
    }
    w.print("}};\n\n#endif // BASIN_POSEIDON_RC_H\n",.{}) catch @panic("OOM");

    return b.addWriteFile("basin_poseidon_rc.h", buf.items);
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