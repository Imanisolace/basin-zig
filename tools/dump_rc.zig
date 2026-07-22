const std = @import("std");

pub fn main()!void {
    const stdout = std.io.getStdOut().writer();
    var rc: [195]u64 = undefined;
    std.crypto.core.sha3.shake256("Basin Poseidon", std.mem.asBytes(&rc));

    try stdout.print("#ifndef BASIN_POSEIDON_RC_H\n",.{});
    try stdout.print("#define BASIN_POSEIDON_RC_H\n",.{});
    try stdout.print("#include <stdint.h>\n\n",.{});
    try stdout.print("#define POSEIDON_WIDTH 3\n",.{});
    try stdout.print("#define POSEIDON_RF 8\n",.{});
    try stdout.print("#define POSEIDON_RP 57\n",.{});
    try stdout.print("#define POSEIDON_ROUNDS 65\n\n",.{});
    try stdout.print("static const uint64_t POSEIDON_MDS[3][3] = {{ {{1,1,1}}, {{1,2,3}}, {{1,4,9}} }};\n\n",.{});
    try stdout.print("static const uint64_t POSEIDON_RC[195] = {{\n",.{});

    for (rc, 0..) |v, i| {
        try stdout.print("0x{x:0>16}ULL",.{v});
        if (i!= 194) try stdout.print(",",.{});
        if (i % 4 == 3) try stdout.print("\n",.{});
    }
    try stdout.print("};\n#endif\n",.{});
}