const std = @import("std");
const package = @import("package");

pub fn packages_write(packages: package.Packages, path: []const u8) !void {
    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    const bytes = std.mem.asBytes(&packages);
    try file.writeAll(bytes);
}
