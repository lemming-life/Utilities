import assembler;

void main(string[] args) {
    if (args.length != 2) { return; }
    try {
        auto assembler = new Assembler(args[1]);
        assembler.run();       
    } catch (Exception e) {
        import std.stdio : writeln;
        e.msg.writeln;
    }
}