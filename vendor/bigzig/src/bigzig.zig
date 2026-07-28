const std = @import("std");

pub fn Int(comptime T: type) type {
    return struct {
        data: T,
        const Self = @This();

        pub fn init(x: T) Self { return .{ .data = x }; }
        pub fn from(comptime U: type, x: U) Self { return .{ .data = @intCast(x) }; }
        pub fn to(self: Self, comptime U: type) U { return @intCast(self.data); }
        
        pub fn add(self: Self, other: Self) Self { return .{ .data = self.data +% other.data }; }
        pub fn sub(self: Self, other: Self) Self { return .{ .data = self.data -% other.data }; }
        pub fn mul(self: Self, other: Self) Self { return .{ .data = self.data *% other.data }; }
        
        pub fn cmp(self: Self, other: Self) std.math.Order {
            if (self.data < other.data) return .lt;
            if (self.data > other.data) return .gt;
            return .eq;
        }
        pub fn mod(self: Self, m: Self) Self { return .{ .data = @rem(self.data, m.data) }; }
    };
}