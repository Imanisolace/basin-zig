const std = @import("std");

pub fn build(b: *std.Build) void {
    const basin_mod = b.addModule("basin", .{
        .root_source_file = b.path("src/basin.zig"),
    });

    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .wasi,
    });

    const wasm = b.addExecutable(.{
        .name = "basin",
        .root_source_file = b.path("src/wasm.zig"),
        .target = wasm_target,
        .optimize = .ReleaseSmall,
    });
    wasm.root_module.addImport("basin", basin_mod);

    wasm.rdynamic = true;
    wasm.root_module.strip = false;
    wasm.entry = .disabled;

    const install_wasm = b.addInstallArtifact(wasm, .{});
    b.getInstallStep().dependOn(&install_wasm.step);

    // CI fix: add a dummy test step so "zig build test" works
    const test_step = b.step("test", "Build wasm for CI");
    test_step.dependOn(b.getInstallStep());
}