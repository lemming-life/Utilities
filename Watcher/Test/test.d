module Test;

class Test {
    override string toString() {
        return "Hello, World!";
    }
}

unittest {
    import std.stdio : writeln;
    auto test = new Test();
    test.toString.writeln;
}