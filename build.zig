const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 1. Make "basin" importable as a Zig module WITH include path
    const basin_mod = b.addModule("basin",.{
       .root_source_file = b.path("src/basin.zig"),
       .target = target,
       .optimize = optimize,
    });
    basin_mod.addIncludePath(b.path("include")); // <- this fixes C import

    // 2. Build the example exe and compile C files into it directly
    const exe = b.addExecutable(.{
       .name = "basin-example",
       .root_source_file = b.path("examples/main.zig"),
       .target = target,
       .optimize = optimize,
    });

    exe.addIncludePath(b.path("include"));
    exe.linkLibC();
    exe.linkSystemLibrary("pthread"); // for threads

    // Add all 4 C files directly to the exe
    exe.addCSourceFiles(.{
       .files = &.{
            "src/basin_config.c",
            "src/basin_init.c",
            "src/basin_poseidon.c",
            "src/basin_parallel.c",
        },
       .flags = &.{ "-std=c99", "-O2" },
    });

    exe.root_module.addImport("basin", basin_mod); // import Zig wrapper
    b.installArtifact(exe);

    // 3. zig build run
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the benchmark example");
    run_step.dependOn(&run_cmd.step);
}
