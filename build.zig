const std = @import("std");

pub fn build(b: *std.Build) void {
    const basin_mod = b.addModule("basin", .{
        .root_source_file = b.path("src/basin.zig"),
    });

    // WASM Target for worker.js
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

    // Zig 0.14 WASM export fixes
    wasm.rdynamic = true; // keep all export fn
    wasm.root_module.strip = false; // don't strip exports

    b.installArtifact(wasm);
}