const std = @import("std");

const common = @import("common.zig");
pub const count = common.count;
pub const bytes = common.bytes;
pub const step = common.step;

extern fn memset_skk64(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8;
extern fn memset_rpkak(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8;

pub fn main() !void {
    const slice = try std.heap.page_allocator.alloc(u8, bytes + 1);

    for (0..count) |_| {
        var ptr = slice.ptr;
        _ = &ptr;
        for (0..bytes / step) |_| {
            _ = memset_rpkak(ptr, 'A', step);
            // _ = memset_skk64(ptr, 'A', step);
            // ptr += step;
        }
    }
}
