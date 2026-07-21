const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Basin C lib
    const basin_mod = b.addModule("basin",.{
       .root_source_file = b.path("src/basin.zig"),
    });

    const basin_c = b.addLibrary(.{
       .name = "basin",
       .linkage =.static,
       .target = target,
       .optimize = optimize,
    });
    basin_c.addCSourceFiles(.{
       .files = &[_][]const u8{
            "src/basin_init.c",
            "src/basin_poseidon.c",
            "src/basin_parallel.c",
        },
       .flags = &[_][]const u8{"-std=c11", "-O3", "-Wall"},
    });
    basin_c.linkLibC();
    basin_c.linkLibCpp(); // for pthread
    basin_mod.linkLibrary(basin_c);

    // Tests
    const tests = b.addTest(.{
       .root_source_file = b.path("tests/run.zig"),
       .target = target,
       .optimize = optimize,
    });
    tests.root_module.addImport("basin", basin_mod);

    // ---- ADD THIS FOR VALGRIND ----
    const skip_heavy = b.option(bool, "skip-heavy", "Skip CPU-intensive/AVX tests") orelse false;
    tests.root_module.addAnonymousImport("build_config",.{
       .root_source_file = b.addWriteFile("build_config.zig",
            b.fmt("pub const skip_heavy = {};",.{skip_heavy})
        ).getPath()
    });
    // ---- END ADD ----

    const install_tests = b.option(bool, "install-tests", "Install the test binary to zig-out/bin") orelse false;
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);

    if (install_tests) {
        const install = b.addInstallArtifact(tests,.{.dest_dir =.{.override =.bin } });
        b.getInstallStep().dependOn(&install.step);
    }

    // Bench exe
    const bench = b.addExecutable(.{
       .name = "basin-bench",
       .root_source_file = b.path("tools/bench.zig"),
       .target = target,
       .optimize =.ReleaseFast,
    });
    bench.root_module.addImport("basin", basin_mod);
    b.installArtifact(bench);
}