const minisign = @embedFile("./external-bin/bin/minisign");
const std = @import("std");
const constants = @import("constants");
const blake3 = std.crypto.hash.Blake3;

const Minisign = struct {
    minisign_file: []const u8,

    pub fn init(allocator: std.mem.Allocator) Minisign {
        const rand = build_random();
        const minisign_file = try std.fmt.allocPrint(allocator, "/tmp/{d}.minisign_file", .{rand});

        var file = try std.fs.createFileAbsolute(minisign_file, .{});
        try file.writeAll(minisign);
        try file.setPermissions(.{ .inner = .{ .mode = 0o755 } });
        defer file.close();

        return Minisign {
            .minisign_file = minisign_file,
        };
    }

    pub fn deinit(self: Minisign) !void {
        del_file(self.minisign_file);
    }

    pub fn sign(self: Minisign, alc: std.mem.Allocator, path: []const u8) !bool {
        const err_msg = std.fmt.allocPrint(alc, "Failed to sign {s}", .{path});
        const args = &[_][]const u8 {
            "-Sm", path
        };
        self.exec(alc, err_msg, args[0..]);
    }

    pub fn exec(self: Minisign, alc: std.mem.Allocator, err_message: []const u8, args: []const []const u8) !bool {

        const exec_args = try std.mem.concat(alc, []const u8, &[_][]const []const u8{
            &[_][]const u8{self.minisign_file},
            args,
        });
        defer alc.free(exec_args);

        var child = std.process.Child.init(exec_args, alc);

        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;
        child.stdin_behavior = .Inherit;

        const result = try child.spawnAndWait();

        if (result != .Exited or result.Exited != 0) {
            std.debug.print("{s}", .{err_message});
            return false;
        }
        return true;
    }
};


fn build_random() u64 {
    var seed: [8]u8 = undefined;
    std.posix.getrandom(std.mem.asBytes(&seed)) catch |err| {
        std.debug.print("Failed to get randomSeed: {any}\n", .{err});
        std.process.exit(1);
    };

    var prng = std.Random.DefaultPrng.init(@as(u64, @bitCast(seed)));
    const rand = prng.random();
    return rand.intRangeAtMost(u64, 0, 3999);
}

fn del_file(file: []const u8) void {
    _ = std.fs.deleteFileAbsolute(file) catch |err| {
        std.debug.print("Failed to delete minisign temp file: {any}\n", .{err});
    };
}
