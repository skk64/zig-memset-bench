const std = @import("std");
const Io = std.Io;

const impl = @import("other_memsets.zig");

pub fn main(init: std.process.Init) !void {
    // Prints to stderr, unbuffered, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();

    // Accessing command line arguments:
    const args = try init.minimal.args.toSlice(arena);
    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }

    // In order to do I/O operations need an `Io` instance.
    const io = init.io;

    const size = try std.fmt.parseInt(usize, args[2], 10);
    const segment_size = try std.fmt.parseInt(usize, args[3], 10);

    const data = try arena.alloc(u8, size);

    const d = bench_memset(memset_fn(args[1]), data, 55, segment_size, io);
    print_time(d);

    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    try stdout_writer.flush(); // Don't forget to flush!
}

fn memset_fn(
    name: []const u8,
) *const fn (dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8 {
    if (std.mem.eql(u8, name, "ericlang")) return impl.memset_ericlang;
    if (std.mem.eql(u8, name, "skk64")) return impl.memset_skk64;
    if (std.mem.eql(u8, name, "builtin")) return impl.memset_builtin;
    if (std.mem.eql(u8, name, "rpkak")) return impl.memset_rpkak;
    if (std.mem.eql(u8, name, "musl_asm")) return impl.memset_musl_asm;
    @panic("not a memset");
}

fn bench_memset(
    memset: *const fn (dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8,
    data: []u8,
    value: u8,
    segment_size: usize,
    io: Io,
) u64 {
    const start = std.Io.Clock.awake.now(io);
    {
        var i: usize = 0;
        while (i + segment_size < data.len) {
            _ = memset(data.ptr + i, value, segment_size);
            i += segment_size;
        }
    }
    const end = Io.Clock.awake.now(io);
    return @intCast(start.durationTo(end).nanoseconds);
}

fn print_time(ns: u64) void {
    std.debug.print("{0:03}:", .{ns / 1_000_000_000});
    std.debug.print("{0:03}:", .{ns / 1_000_000});
    std.debug.print("{0:03}:", .{ns / 1_000});
    std.debug.print("{0:03}\n", .{ns / 1_000});
}
