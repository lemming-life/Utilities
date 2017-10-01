import assembler;

void main(string[] args) {
    if (args.length != 2) { return; }
    try {
        auto assembler = new Assembler(args[1]);
        assembler.run();
        assembler.run();
        // Now VM part
        // auto vm = new Vm(assembler.getMemory, assembler.getFirstInstructionOffset);
        // vm.run();
    } catch (Exception e) {
        import std.stdio : writeln;
        e.msg.writeln;
    }
}