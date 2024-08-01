// DESCRIPTION
//    The wc utility displays the number of lines, words, and bytes contained in each input file,
//    or standard input (if no file is specified) to the standard output.  A line is defined as a
//    string of characters delimited by a ⟨newline⟩ character.  Characters beyond the final
//    ⟨newline⟩ character will not be included in the line count.
//
//    A word is defined as a string of characters delimited by white space characters.  White space
//    characters are the set of characters for which the iswspace(3) function returns true.  If
//    more than one input file is specified, a line of cumulative counts for all the files is
//    displayed on a separate line after the output for the last file.
//
//    The following options are available:
//
//    --libxo
//            Generate output via libxo(3) in a selection of different human and machine readable
//            formats.  See xo_parse_args(3) for details on command line arguments.
//
//    -L      Write the length of the line containing the most bytes (default) or characters (when
//            -m is provided) to standard output.  When more than one file argument is specified,
//            the longest input line of all files is reported as the value of the final “total”.
//
//    -c      The number of bytes in each input file is written to the standard output.  This will
//            cancel out any prior usage of the -m option.
//
//    -l      The number of lines in each input file is written to the standard output.
//
//    -m      The number of characters in each input file is written to the standard output.  If
//            the current locale does not support multibyte characters, this is equivalent to the
//            -c option.  This will cancel out any prior usage of the -c option.
//
//    -w      The number of words in each input file is written to the standard output.
//
//    When an option is specified, wc only reports the information requested by that option.  The
//    order of output always takes the form of line, word, byte, and file name.  The default action
//    is equivalent to specifying the -c, -l and -w options.
//
//    If no files are specified, the standard input is used and no file name is displayed.  The
//    prompt will accept input until receiving EOF, or [^D] in most environments.
//
//    If wc receives a SIGINFO (see the status argument for stty(1)) signal, the interim data will
//    be written to the standard error output in the same format as the standard completion
//    message.

const std = @import("std");

const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

const Flag = enum {
    length, // -L (default)
    count, // -c
    lines, // -l
    characters, // -m
    words, // -w
};

const Flags = struct {
    length: bool = false,
    count: bool = false,
    lines: bool = false,
    characters: bool = false,
    words: bool = false,
};

const ArgParseError = error{
    MissingPathname,
    InvalidFormat,
};

fn parse_arguments() ArgParseError!struct { pathname: []const u8, flags: Flags } {
    var pathname: ?[]const u8 = null;
    var flags = Flags{};

    var args = std.process.args();
    _ = args.skip(); // skip the command statement

    while (true) {
        const current_arg = args.next();
        if (current_arg == null) break;
        const unwrapped_current_arg = current_arg.?;

        if (unwrapped_current_arg[0] == '-') {
            for (unwrapped_current_arg[1..]) |flag| {
                switch (flag) {
                    'L' => flags.length = true,
                    'c' => flags.count = true,
                    'l' => flags.lines = true,
                    'm' => flags.characters = true,
                    'w' => flags.words = true,
                    else => std.debug.print("invalid flag\n", .{}),
                }
            }
        } else {
            pathname = unwrapped_current_arg;
            if (args.next() != null) return ArgParseError.InvalidFormat;
            break;
        }
    }

    if (pathname == null) return ArgParseError.MissingPathname;

    // default to -L
    if (!flags.length and !flags.count and !flags.lines and !flags.characters and !flags.words) flags.length = true;
    return .{ .pathname = pathname.?, .flags = flags };
}

fn readFileAsBytes(pathname: []const u8) ![]u8 {
    const allocator = std.heap.page_allocator;

    const file = try std.fs.cwd().openFile(pathname, .{});
    defer file.close();

    const bytes = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    return bytes;
}

fn countLines(bytes: *const []u8) usize {
    var count: usize = 0;
    var tokenizer = std.mem.tokenizeSequence(u8, bytes.*, "\n");
    while (tokenizer.next() != null) {
        count += 1;
    }
    return count;
}

fn countWords(bytes: *const []u8) usize {
    var count: usize = 0;
    var tokenizer = std.mem.tokenizeScalar(u8, bytes.*, ' ');
    while (tokenizer.next() != null) {
        count += 1;
    }
    return count;
}

fn countCharacters(bytes: *const []u8) usize {
    var count: usize = 0;
    for (bytes.*) |_| {
        count += 1;
    }
    return count;
}

pub fn main() !void {
    const result = try parse_arguments();
    const pathname = result.pathname;
    const flags = result.flags;
    const bytes = readFileAsBytes(pathname) catch |err| {
        try stderr.print("Error reading file: {}\n", .{err});
        return;
    };

    // std.debug.print("Pathname: {s}\n", .{pathname});
    // std.debug.print("Flags: length={}, count={}, lines={}, characters={}, words={}\n", .{
    //     flags.length,
    //     flags.count,
    //     flags.lines,
    //     flags.characters,
    //     flags.words,
    // });

    try stdout.print("  ", .{});

    if (flags.count) {
        try stdout.print("{}  ", .{bytes.len});
    }

    if (flags.lines) {
        try stdout.print("{}  ", .{countLines(&bytes)});
    }

    if (flags.characters) {
        try stdout.print("{}  ", .{countCharacters(&bytes)});
    }

    if (flags.words) {
        try stdout.print("{}  ", .{countWords(&bytes)});
    }

    try stdout.print("{s}", .{pathname});
}

// test "simple test" {
//     var list = std.ArrayList(i32).init(std.testing.allocator);
//     defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
//     try list.append(42);
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }
