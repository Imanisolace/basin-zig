const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Static library with your C code
    const lib = b.addStaticLibrary(.{
       .name = "basin",
       .target = target,
       .optimize = optimize,
    });

    // Let C code find basin.h
    lib.addIncludePath("include"); // <- FIXED: no .path

    // Add all your C source files
    lib.addCSourceFiles(.{
       .files = &.{
            "src/basin_config.c",
            "src/basin_init.c", 
            "src/basin_hash.c",
            "src/basin_parallel.c",
        },
       .flags = &.{ "-O2", "-Wall" },
    });

    b.installArtifact(lib);

    // Test executable that links the C lib
    const lib_unit_tests = b.addTest(.{
       .root_source_file = "src/basin.zig", // <- FIXED: no .path
       .target = target,
       .optimize = optimize,
    });

    lib_unit_tests.addIncludePath("include"); // <- FIXED
    lib_unit_tests.linkLibrary(lib);
    lib_unit_tests.linkLibC(); // important for C

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}