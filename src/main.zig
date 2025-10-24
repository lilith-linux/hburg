const std = @import("std");
const eql = std.mem.eql;

const build = @import("build");

const help_message = @embedFile("./templates/help_message");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);

    if (args.len < 2) {
        try display_help();
        std.process.exit(1);
    }

    if (eql(u8, args[1], "build")) {
        try build.build();
    }

    return;
}

fn display_help() !void {
    std.debug.print("{s}\n", .{help_message});
}
