const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create static library
    const lib = b.addStaticLibrary(.{
        .name = "basin",
        .target = target,
        .optimize = optimize,
    });

    // Include path for basin.h
    lib.addIncludePath(b.path("include"));
    
    // THIS IS THE FIX: tell zig to use system C headers like string.h, stdlib.h
    lib.linkLibC();

    // All 4 C source files
    lib.addCSourceFiles(.{
        .files = &.{
            "src/basin_config.c",
            "src/basin_init.c",
            "src/basin_poseidon.c",
            "src/basin_parallel.c",
        },
        .flags = &.{ "-O2", "-Wall" },
    });

    // Install the library
    b.installArtifact(lib);

    // Unit tests
    const tests = b.addTest(.{
        .root_source_file = b.path("src/basin.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    tests.addIncludePath(b.path("include"));
    tests.linkLibrary(lib);
    tests.linkLibC(); // tests also need libc

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
