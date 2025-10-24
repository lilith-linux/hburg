const std = @import("std");
const eql = std.mem.eql;

const update = @import("update");
const install = @import("install");

const help_message = @embedFile("./templates/help_message");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);

    if (args.len < 2) {
        try display_help();
        std.process.exit(1);
    }

    return;
}

fn display_help() !void {
    std.debug.print("{s}\n", .{help_message});
}
