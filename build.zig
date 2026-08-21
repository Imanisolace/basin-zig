const std = @import("std");

pub fn build(b: *std.Build) void {
    const bigzig_mod = b.addModule("bigzig", .{
        .root_source_file = b.path("vendor/bigzig/src/bigzig.zig"),
    });

    const fr_mod = b.addModule("fr", .{
        .root_source_file = b.path("src/fr.zig"),
    });
    fr_mod.addImport("bigzig", bigzig_mod);

    const poseidon_consts_mod = b.addModule("poseidon_consts", .{
        .root_source_file = b.path("src/poseidon_consts.zig"),
    });
    poseidon_consts_mod.addImport("fr", fr_mod);

    const basin_mod = b.addModule("basin", .{
        .root_source_file = b.path("src/basin.zig"),
    });
    basin_mod.addImport("fr", fr_mod);
    basin_mod.addImport("poseidon_consts", poseidon_consts_mod);

    const merkle_mod = b.addModule("merkle", .{
        .root_source_file = b.path("src/merkle.zig"),
    });
    merkle_mod.addImport("basin", basin_mod);
    merkle_mod.addImport("fr", fr_mod);

    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    const wasm = b.addExecutable(.{
        .name = "basin",
        .root_source_file = b.path("src/wasm.zig"),
        .target = wasm_target,
        .optimize = .ReleaseSmall,
    });
    wasm.root_module.addImport("basin", basin_mod);
    wasm.root_module.addImport("merkle", merkle_mod);

    wasm.rdynamic = true;
    wasm.root_module.strip = false;
    wasm.entry = .disabled;

    const install_wasm = b.addInstallArtifact(wasm, .{});
    b.getInstallStep().dependOn(&install_wasm.step);

    const copy_wasm = b.addInstallFileWithDir(
        wasm.getEmittedBin(),
        .{ .custom = "../src" },
        "basin.wasm",
    );
    copy_wasm.step.dependOn(&install_wasm.step);
    b.getInstallStep().dependOn(&copy_wasm.step);

    const test_target = b.standardTargetOptions(.{});

    const build_config_mod = b.createModule(.{
        .root_source_file = b.addWriteFiles().add(
            "build_config.zig",
            "pub const skip_heavy = false;\n",
        ),
    });

    const tests = b.addTest(.{
        .root_source_file = b.path("tests/run.zig"),
        .target = test_target,
        .optimize = .Debug,
    });
    tests.root_module.addImport("basin", basin_mod);
    tests.root_module.addImport("merkle", merkle_mod);
    tests.root_module.addImport("fr", fr_mod);
    tests.root_module.addImport("poseidon_consts", poseidon_consts_mod);
    tests.root_module.addImport("build_config", build_config_mod);

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run the test suite");
    test_step.dependOn(&run_tests.step);
}