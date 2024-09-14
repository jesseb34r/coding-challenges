const std = @import("std");

fn readFileAsBytes(pathname: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(pathname, .{});
    defer file.close();

    return try file.readToEndAlloc(std.heap.page_allocator, std.math.maxInt(usize));
}

fn readInputFromStdin() ![]u8 {
    return try std.io.getStdIn().readToEndAlloc(std.heap.page_allocator, std.math.maxInt(usize));
}

const StringHashContext = struct {
    fn hasher(key: []const u8) u64 {
        return std.hash.hash(u64, key);
    }

    fn eql(a: []const u8, b: []const u8) bool {
        return std.mem.eql(u8, a, b);
    }
};

const HashMap = std.ArrayHashMap([]const u8, *JsonValue, StringHashContext, true);

const JsonValue = union(enum) {
    Null,
    Bool: bool,
    Number: f64,
    String: []const u8,
    Array: std.ArrayList(*JsonValue),
    Object: HashMap,

    pub fn equals(self: *const JsonValue, other: *const JsonValue) bool {
        return switch (self.*) {
            JsonValue.Null => switch (other.*) {
                JsonValue.Null => true,
                else => false,
            },
            JsonValue.Bool => switch (other.*) {
                JsonValue.Bool => self.*.Bool == other.*.Bool,
                else => false,
            },
            JsonValue.Number => switch (other.*) {
                JsonValue.Number => self.*.Number == other.*.Number,
                else => false,
            },
            JsonValue.String => switch (other.*) {
                JsonValue.String => std.mem.eql(u8, self.*.String, other.*.String),
                else => false,
            },
            JsonValue.Array => switch (other.*) {
                JsonValue.Array => array: {
                    if (self.*.Array.items.len != other.*.Array.items.len) return false;
                    for (self.*.Array.items, 0..) |*elem, i| {
                        if (!elem.*.equals(other.*.Array.items[i])) return false;
                    }
                    break :array true;
                },
                else => false,
            },
            JsonValue.Object => switch (other.*) {
                JsonValue.Object => object: {
                    if (self.*.Object.count() != other.*.Object.count()) break :object false;

                    var it = self.*.Object.iterator();
                    while (it.next()) |entry| {
                        const other_value = other.*.Object.get(entry.key_ptr.*);
                        if (other_value == null) break :object false;
                        if (!entry.value_ptr.*.equals(other_value.?)) break :object false;
                    }
                    break :object true;
                },
                else => false,
            },
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
