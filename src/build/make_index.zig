const std = @import("std");

pub fn make_index(allocator: std.mem.Allocator) !bool {
    var packages = std.ArrayList([]const u8){};
    defer {
        for (packages.items) |items| {
            allocator.free(items);
        }
        packages.deinit(allocator);
    }

    const dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();

    var iterate = dir.iterate();
    for (iterate.next()) |entry| {
        const ext = std.fs.path.extension(entry.name);
        if (std.mem.eql(u8, ext, ".hb")) {
            const entry_copy = try allocator.dupe(u8, entry.name);
            packages.append(allocator, entry_copy);
        }
    }
}

fn get_value(alc: std.mem.Allocator, file: []const u8, value: []const u8) ![]const u8 {
    const child = std.process.Child.init(&.{ "/usr/bin/sh", ". " ++ file, "echo \"$" ++ value ++ "\"" }, alc);

    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.stdin_behavior = .Ignore;

    const result = try child.spawnAndWait();

    if (result != .Exited or result.Exited != 0) {
        return error.SpawnError;
    }

    const stdout = child.stdout.?;
    var buffer: []u8 = undefined;

    try stdout.readAll(&buffer);
    return buffer;
}
