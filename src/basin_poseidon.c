const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const c_files = &.{
        "src/poseidon.c",
        "src/poseidon_rc.c",
        "src/basin_config.c",
        "src/basin_init.c",
        "src/basin_parallel.c"
    };
    const c_flags = &[_][]const u8{"-O2", "-std=c11", "-Wall"};

    const lib = b.addStaticLibrary(.{.name = "basin",.target = target,.optimize = optimize});
    lib.addIncludePath(b.path("include"));
    lib.linkLibC();
    lib.addCSourceFiles(.{.files = c_files,.flags = c_flags});
    b.installArtifact(lib);

    const tests = b.addTest(.{.root_source_file = b.path("tests/run.zig"),.target = target,.optimize =.ReleaseSafe});
    tests.addIncludePath(b.path("include"));
    tests.linkLibC();
    tests.addCSourceFiles(.{.files = c_files,.flags = c_flags});
    b.step("test", "Run tests").dependOn(&b.addRunArtifact(tests).step);
}
