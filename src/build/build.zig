const std = @import("std");
const info = @import("info").info;
const make_index = @import("make_index");
const Blake3 = std.crypto.hash.Blake3;

const HashJob = struct {
    path: []const u8,
    output: []const u8,
    allocator: std.mem.Allocator,
};

const ProgressState = struct {
    mutex: std.Thread.Mutex = .{},
    completed: u64 = 0,
    total: u64 = 0,
    current_file: []const u8 = "",
    allocator: std.mem.Allocator,

    fn updateProgress(self: *ProgressState, file: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.current_file.len > 0) {
            self.allocator.free(self.current_file);
        }
        self.current_file = try self.allocator.dupe(u8, file);
        self.completed += 1;

        const percent = (self.completed * 100) / self.total;

        try info(self.allocator, "\r\x1b[2K", .{});
        try info(self.allocator, "hashing: {d}% ({d}/{d}) - {s}", .{
            percent,
            self.completed,
            self.total,
            file,
        });
    }

    fn cleanup(self: *ProgressState) void {
        if (self.current_file.len > 0) {
            self.allocator.free(self.current_file);
        }
    }
};

fn hash_file(allocator: std.mem.Allocator, path: []const u8) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var hasher = Blake3.init(.{});
    var buffer: [1024 * 1024]u8 = undefined;

    while (true) {
        const bytes_read = try file.read(&buffer);
        if (bytes_read == 0) break;
        hasher.update(buffer[0..bytes_read]);
    }

    var hash: [32]u8 = undefined;
    hasher.final(&hash);

    var hex_string = std.ArrayList(u8){};
    defer hex_string.deinit(allocator);

    const writer = hex_string.writer(allocator);
    for (hash) |byte| {
        try writer.print("{x:0>2}", .{byte});
    }

    const output = try std.fmt.allocPrint(allocator, "{s}.b3", .{path});
    defer allocator.free(output);

    const output_file = try std.fs.cwd().createFile(output, .{});
    defer output_file.close();

    try output_file.writeAll(hex_string.items);
}

fn hashWorker(job: HashJob) !void {
    try hash_file(job.allocator, job.path);
}

pub fn build(allocator: std.mem.Allocator) !void {
    var dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();

    var checklist = std.ArrayList([]const u8){};
    defer {
        for (checklist.items) |item| {
            allocator.free(item);
        }
        checklist.deinit(allocator);
    }

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        const ext = std.fs.path.extension(entry.name);
        if (std.mem.eql(u8, ext, ".clos") or std.mem.eql(u8, ext, ".hb")) {
            const output = try std.fmt.allocPrint(allocator, "{s}.b3", .{entry.name});
            defer allocator.free(output);
            if (exists(output)) {
                continue;
            }
            const name_copy = try allocator.dupe(u8, entry.name);
            try checklist.append(allocator, name_copy);
            try info(allocator, "\r\x1b[2Kfound: {d} files", .{checklist.items.len});
        }
    }

    if (checklist.items.len == 0) {
        try info(allocator, "No new .clos files found.\n", .{});
        try create_index(allocator);
        return;
    }

    var progress = ProgressState{
        .total = checklist.items.len,
        .allocator = allocator,
    };
    defer progress.cleanup();

    // thread pool initialize
    var thread_pool: std.Thread.Pool = undefined;
    try thread_pool.init(.{ .allocator = allocator });
    defer thread_pool.deinit();

    var wg = std.Thread.WaitGroup{};

    for (checklist.items) |file| {
        const out_file = try std.fmt.allocPrint(allocator, "{s}.hash", .{file});

        const job = HashJob{
            .path = file,
            .output = out_file,
            .allocator = allocator,
        };

        wg.start();
        try thread_pool.spawn(hashWorkerWrapper, .{ job, &wg, &progress });
    }

    thread_pool.waitAndWork(&wg);
    std.debug.print("\n", .{});
    try create_index(allocator);
}

fn create_index(allocator: std.mem.Allocator) !void {
    std.debug.print("index: progress", .{});
    const avail = try make_index.make_index(allocator);
    if (avail) {
        std.debug.print("\r\x1b[2Kindex created to {s}\n", .{"index"});
    } else {
        std.debug.print("\r\x1b[2Kindex create failed\n", .{});
        return;
    }

    std.debug.print("index: hashing", .{});
    try hash_file(allocator, "index");
    std.debug.print("\r\x1b[2Kindex: hash done\n", .{});
}

fn hashWorkerWrapper(
    job: HashJob,
    wg: *std.Thread.WaitGroup,
    progress: *ProgressState,
) void {
    defer {
        job.allocator.free(job.output);
        wg.finish();
    }

    hashWorker(job) catch |err| {
        std.debug.print("\nError hashing {s}: {any}\n", .{ job.path, err });
        return;
    };

    progress.updateProgress(job.path) catch {};
}

fn exists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}
