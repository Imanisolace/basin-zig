const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const basin_mod = b.addModule("basin",.{
      .root_source_file = b.path("src/basin.zig"),
    });

    // WASM Target for worker.js
    const wasm_target = b.resolveTargetQuery(.{
      .cpu_arch =.wasm32,
      .os_tag =.wasi,
    });
    const wasm = b.addExecutable(.{
      .name = "basin",
      .root_source_file = b.path("src/wasm.zig"),
      .target = wasm_target,
      .optimize =.ReleaseSmall,
    });
    wasm.root_module.addImport("basin", basin_mod);
    wasm.export_symbol_names = &[_][]const u8{
        "set_leaf_byte", "api_compute_root", "api_generate_proof", "api_verify_proof",
        "get_root_ptr", "get_proof_len", "get_proof_step_side", "get_proof_step_sibling_ptr", "write_proof_data"
    };
    b.installArtifact(wasm);
}