const std = @import("std");

pub fn main()!void {
    var rc: [195]u64 = undefined;
    std.crypto.core.sha3.shake256("Basin Poseidon", std.mem.asBytes(&rc));

    const stdout = std.io.getStdOut().writer();
    try stdout.print("#ifndef BASIN_POSEIDON_RC_H\n#define BASIN_POSEIDON_RC_H\n#include <stdint.h>\n\nstatic const uint64_t POSEIDON_RC[195] = {{\n",.{});

    for (rc, 0..) |v, i| {
        try stdout.print("0x{x:0>16}ULL",.{v});
        if (i!= rc.len - 1) try stdout.print(",",.{});
        if (i % 3 == 2) try stdout.print("\n",.{});
    }
    try stdout.print("}};\n\n#endif // BASIN_POSEIDON_RC_H\n",.{});
}
