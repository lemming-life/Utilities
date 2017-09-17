module Test;

class Test {
    override string toString() {
        return "Hello, World!";
    }
}

unittest {
    auto test = new Test();
    assert(test.toString == "Hello, World!");
}