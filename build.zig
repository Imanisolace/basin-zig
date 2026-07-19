const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 1. Make "basin" importable as a Zig module
    const basin_mod = b.addModule("basin", .{
        .root_source_file = b.path("src/basin.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 2. Build the C library
    const lib = b.addLibrary(.{
        .name = "basin",
        .linkage = .static,
        .target = target,
        .optimize = optimize,
    });

    lib.addIncludePath(b.path("include"));
    lib.linkLibC();
    lib.linkSystemLibrary("pthread"); // <- needed for 8 threads

    // Add all 4 C files
    lib.addCSourceFiles(.{
        .files = &.{
            "src/basin_config.c",
            "src/basin_init.c", 
            "src/basin_poseidon.c",
            "src/basin_parallel.c",
        },
        .flags = &.{},
    });
    b.installArtifact(lib);

    // 3. Build the example and link it to the C lib + Zig module
    const exe = b.addExecutable(.{
        .name = "basin-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.addIncludePath(b.path("include"));
    exe.linkLibrary(lib); // link C
    exe.root_module.addImport("basin", basin_mod); // import Zig wrapper
    b.installArtifact(exe);

    // 4. zig build run
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the benchmark example");
    run_step.dependOn(&run_cmd.step);
}