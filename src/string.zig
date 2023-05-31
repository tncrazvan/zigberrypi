const std = @import("std");

pub fn string(comptime value: []const u8, args: anytype) ![]const u8 {
    const list = std.ArrayList(u8).init(std.heap.page_allocator);
    defer list.deinit();
    const allocator = list.allocator;
    const result = try std.fmt.allocPrint(
        allocator,
        value,
        args,
    );

    return result;
}
