const help_message = @embedFile("./templates/help_message");
const std = @import("std");
const eql = std.mem.eql;
const make_hb = @import("make");
const build = @import("build");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);

    if (args.len < 2) {
        try display_help();
        std.process.exit(1);
    }

    if (eql(u8, args[1], "build")) {
        try build.build(allocator);
    } else if (eql(u8, args[1], "make")) {
        if (args.len < 3) {
            std.debug.print("Usage: hburg make <FILE>\n", .{});
            std.process.exit(1);
        }
        try make_hb.make(allocator, args[2]);
    }

    return;
}

fn display_help() !void {
    std.debug.print("{s}\n", .{help_message});
}
