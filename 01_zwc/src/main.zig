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

const Flags = struct {
    count: bool, // bytes in file
    lines: bool,
    words: bool,
    characters: bool,
};

const ArgParseError = error{
    MissingPathname,
    InvalidFormat,
    InvalidFlag,
};

fn parseFlags(flags_input: []const u8) ArgParseError!Flags {
    var flags = Flags{
        .count = false,
        .lines = false,
        .words = false,
        .characters = false,
    };

    for (flags_input[1..]) |flag| {
        switch (flag) {
            'c' => {
                flags.characters = false;
                flags.count = true;
            },
            'l' => flags.lines = true,
            'w' => flags.words = true,
            'm' => {
                flags.count = false;
                flags.characters = true;
            },
            else => return ArgParseError.InvalidFlag,
        }
    }

    return flags;
}

/// Command structure should be `zwc <flags> <pathname>`
/// flags are always preceded with a `-`
/// initial implementation is just one flag group and one pathname
/// final should allow any number of flag strings and handle priority and order as well as any number of
/// pathnames and list stats for all files as well as sums
fn parseArguments() ArgParseError!struct { pathname: []const u8, flags: Flags } {
    var args_it = std.process.args();

    const default_flags = Flags{
        .count = true,
        .lines = false,
        .words = false,
        .characters = false,
    };

    _ = args_it.skip(); // skip the command statement

    const first_arg = args_it.next();
    if (first_arg == null) {
        return ArgParseError.MissingPathname;
    } else if (first_arg.?[0] != '-') {
        if (args_it.next() != null) {
            return ArgParseError.InvalidFormat;
        } else {
            return .{ .pathname = first_arg.?, .flags = default_flags };
        }
    } else {
        const second_arg = args_it.next();
        if (second_arg == null) {
            return ArgParseError.MissingPathname;
        } else if (second_arg.?[0] == '-') {
            return ArgParseError.InvalidFormat;
        } else {
            return .{ .pathname = second_arg.?, .flags = try parseFlags(first_arg.?) };
        }
    }
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

fn countCharacters(bytes: *const []u8) !usize {
    return try std.unicode.utf8CountCodepoints(bytes.*);
}

pub fn main() !void {
    const result = try parseArguments();
    const bytes = readFileAsBytes(result.pathname) catch |err| {
        try stderr.print("Error reading file: {}\n", .{err});
        return;
    };

    try stdout.print("  ", .{});

    if (result.flags.count) try stdout.print("{}  ", .{bytes.len});
    if (result.flags.lines) try stdout.print("{}  ", .{countLines(&bytes)});
    if (result.flags.words) try stdout.print("{}  ", .{countWords(&bytes)});
    if (result.flags.characters) try stdout.print("{}  ", .{try countCharacters(&bytes)});

    try stdout.print("{s}", .{result.pathname});
}

test "flags parsing" {
    try std.testing.expect(testFlagsEqual(Flags{
        .count = true,
        .lines = false,
        .words = false,
        .characters = false,
    }, try parseFlags("-c")));
    try std.testing.expect(testFlagsEqual(Flags{
        .count = true,
        .lines = true,
        .words = false,
        .characters = false,
    }, try parseFlags("-cl")));
    try std.testing.expect(testFlagsEqual(Flags{
        .count = true,
        .lines = true,
        .words = true,
        .characters = false,
    }, try parseFlags("-clw")));
    try std.testing.expect(testFlagsEqual(Flags{
        .count = false,
        .lines = true,
        .words = true,
        .characters = true,
    }, try parseFlags("-clwm")));
    try std.testing.expect(testFlagsEqual(Flags{
        .count = false,
        .lines = true,
        .words = true,
        .characters = true,
    }, try parseFlags("-lwm")));
}

test "args parsing" {
    // try testParseCmdLine("zwc -w test.txt", .{ .pathname = "test.txt", .flags = Flags{ .count = false, .lines = false, .words = true, .characters = false } });
}

fn testFlagsEqual(
    flags_a: Flags,
    flags_b: Flags,
) bool {
    return flags_a.count == flags_b.count and flags_a.lines == flags_b.lines and flags_a.words == flags_b.words and flags_a.characters == flags_b.characters;
}

fn testParseCmdLine(input_cmd_line: []const u8, expected_args: struct { pathname: []const u8, flags: Flags }) !void {
    var it = try std.process.ArgIteratorGeneral(.{}).init(std.testing.allocator, input_cmd_line);
    defer it.deinit();

    const parsed_args = try parseArguments(it.cast(std.testing.ArgIterator));

    try std.testing.expectEqualStrings(expected_args.pathname, parsed_args.pathname);
    try std.testing.expect(testFlagsEqual(expected_args.flags, parsed_args.flags));
}
