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

fn readFileAsBytes(pathname: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(pathname, .{});
    defer file.close();

    return try file.readToEndAlloc(std.heap.page_allocator, std.math.maxInt(usize));
}

fn readInputFromStdin() ![]u8 {
    return try std.io.getStdIn().readToEndAlloc(std.heap.page_allocator, std.math.maxInt(usize));
}

const JsonValue = union(enum) {
    Null,
    Bool: bool,
    Number: f64,
    String: []const u8,
    Array: std.ArrayList(*JsonValue),
    Object: std.AutoArrayHashMap([]const u8, *JsonValue),

    pub fn equals(self: *const JsonValue, other: *const JsonValue) bool {
        return switch (self.*) {
            JsonValue.Null => switch (other.*) {
                JsonValue.Null => true,
                else => false,
            },
            JsonValue.Bool => |value| switch (other.*) {
                JsonValue.Bool => |other_value| value == other_value,
                else => false,
            },
            JsonValue.Number => |value| switch (other.*) {
                JsonValue.Number => |other_value| value == other_value,
                else => false,
            },
            else => false,
        };
    }
};

const ParseError = error{InvalidJson};

fn parseJsonValue(input: []u8) !JsonValue {
    if (input.len == 0) return ParseError.InvalidJson;
    if (input.len > 0 and input[0] != '{') return ParseError.InvalidJson;

    const return_value: JsonValue = .Null;
    return return_value;
}

pub fn main() !void {
    // const pathnames = std.process.args();

    // try stdout.print("  ", .{});

}

test "step one" {
    const invalid_json_pathname = "/Users/jesseaubin/dev/coding-challenges/02_zjson/tests/step1/invalid.json";
    try std.testing.expectError(ParseError.InvalidJson, parseJsonValue(try readFileAsBytes(invalid_json_pathname)));

    const valid_json_pathname = "/Users/jesseaubin/dev/coding-challenges/02_zjson/tests/step1/valid.json";
    const parsed_valid_json = try parseJsonValue(try readFileAsBytes(valid_json_pathname));
    try std.testing.expect(parsed_valid_json.equals(@as(*const JsonValue, &.Null)));
}
