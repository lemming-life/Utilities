module assembler;
import convenience, enums, token, scanner;

class Assembler {
    import std.algorithm : canFind;
    import std.file : exists;
    import std.stdio : writeln;

    public:
    byte[] getMemory() { return memory; }
    int[string] getLabels() { return labels; }
    uint getFirstInstructionOffset() { return firstInstructionOffset; }

    this(string file, byte[] memory = new byte[1_000_000]) {
        if (!file.exists) { throw new Exception("File does not exist."); }
        this.file = file;
        this.memory = memory;
        currentPass = Pass.NILL;
    }

    void run() {
        // First pass: ensure syntax is correct, build up labels with correct offsets.
        // Second pass: byte code generation
        try{
            scanner = new Scanner(file);
            currentPass = currentPass == Pass.NILL ? Pass.FIRST : Pass.SECOND;
            inDataSegment = true;
            offset = 0;
            while(true) {
                switch(token.type) {
                case TokenType.EOF:                     return;
                case TokenType.INVALID:                 throw new Exception("Unsupported symbol.");
                case TokenType.WS, TokenType.COMMENT:   scanner.getNextToken;   break;
                default:                                analyze;                break;
                }
            }
        } catch (Exception e) {
            throw new Exception(token.lineNumber.to_s ~ ": " ~ e.msg ~ " Token text: " ~ token.text);
        }
    }

    private:
    Scanner scanner;
    string file;
    Pass currentPass;
    bool inDataSegment;
    int[string] labels;
    byte[] memory;
    uint offset;
    uint firstInstructionOffset;
    bool inInstruction;

    /// Makes it a bit easier to call scanner token
    Token token() {
        return scanner.token.type == TokenType.NONE ? scanner.getNextToken : scanner.token;
    }

    void analyze() {
        switch(token.type) {
        case TokenType.LABEL:       label;          break;
        case TokenType.DIRECTIVE:   directive;      break;
        case TokenType.OPCODE:      instruction;    break;
        default: throw new Exception("Expecting label/directive/opcode.");
        }
    }

    void directive() {
        debug{ ("directive is " ~ token.text).writeln; }
        if (!inDataSegment) throw new Exception("Directive in non data segment.");
        switch(to_member!Directive(token.text[1 .. $])) {
        case Directive.INT: scanner.getNextToken;   checkWS;    integer;       break;
        case Directive.BYT: scanner.getNextToken;   checkWS;    character;     break;
        default: throw new Exception("Expecting a directive.");
        }
    }

    void instruction() {
        debug { ("instruction is " ~ token.text).writeln; }
        if (inDataSegment) {
            inDataSegment = false;
            firstInstructionOffset = offset;
        }
        auto opcode = to_member!Opcode(token.text);
        if (!to_array!Opcode().canFind(opcode)) throw new Exception("Expecting opcode.");
        scanner.getNextToken;
        if (![Opcode.END, Opcode.BLK].canFind(opcode)) checkWS;

        if (currentPass == Pass.SECOND) memory.writeTo!int(opcode, offset);
        inInstruction = true;
        auto originalOffset = offset;
        offset += Offset.INT;

        final switch(opcode) {
        case Opcode.END, Opcode.BLK:                                                                         break;
        case Opcode.TRP:                                         trap;                                       break;
        case Opcode.JMP, Opcode.LCK, Opcode.ULK:                 label;                                      break;
        case Opcode.JMR:                                         register;                                   break;
        case Opcode.ADI:                                         register;   checkWS;    integer;            break;
        case Opcode.STRI,Opcode.LDRI,Opcode.STBI,Opcode.LDBI:    register;   checkWS;    register;           break;
        case Opcode.STR, Opcode.LDR, Opcode.STB, Opcode.LDB:     register;   checkWS;    label_or_register;  break;
        case Opcode.BNZ, Opcode.BGT, Opcode.BLT, Opcode.BRZ, 
             Opcode.LDA, Opcode.RUN:                             register;   checkWS;    label;              break;
        case Opcode.MOV, Opcode.ADD, Opcode.SUB, Opcode.OR,
             Opcode.MUL, Opcode.DIV, Opcode.AND, Opcode.CMP:     register;   checkWS;    register;           break;
        }
        
        offset = originalOffset + Offset.INSTR;
        inInstruction = false;
    }

    void label() {
        debug{ ("label is " ~ token.text).writeln; }
        if (token.type != TokenType.LABEL) throw new Exception("Expecting label.");

        if (currentPass == Pass.FIRST) {
            if (!inInstruction) {
                if (token.text in labels) throw new Exception("Duplicate labels.");
                labels[token.text] = offset;
            }
        } else if(currentPass == Pass.SECOND && inInstruction) {
            memory.writeTo(labels[token.text] ,offset);
        }
        scanner.getNextToken;
    }

    void register() {
        debug { ("register is " ~ token.text).writeln; }
        if (token.type != TokenType.REGISTER) throw new Exception("Expecting register.");
        if (currentPass == Pass.SECOND) memory.writeTo(to_member!Register(token.text), offset);
        //writeToMemory!int(to_member!Register(token.text), offset); 
         //*(cast(int*)(&memory + offset)) = to_member!Register(token.text);
        scanner.getNextToken;
    }

    void label_or_register() {
        debug { ("label or register is " ~ token.text).writeln; }
        switch(token.type) {
        case TokenType.LABEL:       label;      break;
        case TokenType.REGISTER:
            if (currentPass == Pass.SECOND && inInstruction) {
                // Need to correct register
                auto opcodeOffset = offset - 8;
                auto newOpcode = memory.readFrom!int(opcodeOffset) - 4;
                memory.writeTo(newOpcode, opcodeOffset);
            }
            register;   break;
        default: throw new Exception("Expecting label or register.");
        }
    }

    void checkWS() {
        debug { ("checkWS is " ~ token.text).writeln; }
        if (token.type != TokenType.WS) throw new Exception("Expecting white space.");
        scanner.getNextToken;
    }

    void integer() {
        debug { ("int is " ~ token.text).writeln; }
        if (token.type != TokenType.INT) throw new Exception("Expecting integer.");
        if (currentPass == Pass.SECOND) memory.writeTo(token.to_i, offset);
        scanner.getNextToken;
        offset += Offset.INT;
    }

    void character() {
        debug { ("char is " ~ token.text).writeln; }
        if (token.type != TokenType.CHAR) throw new Exception("Expecting character.");
        if (currentPass == Pass.SECOND) memory.writeTo(token.to_c, offset);
        scanner.getNextToken;
        offset += Offset.BYT;
    }

    void trap() {
        debug { ("trap is " ~ token.text).writeln; }
        if (token.type != TokenType.INT || !to_array_values!Trap().canFind(token.text) )
            throw new Exception("Expecting valid trap number.");
        
        if (currentPass == Pass.SECOND) memory.writeTo(token.to_i, offset);
        scanner.getNextToken;
    }


} // End Assembler


unittest {
    import std.file : exists, remove;
    import std.stdio : File, writeln;
    import std.conv : to;

    debug { "\n\nBEGINNING assembler.d unittest".writeln; }

    {
        // Begin syntax test (1st pass), also check labels.
        string file = "test.asm";
        scope(exit) { if (file.exists) file.remove; }
        
        { File(file, "w").write(r"
        ; Directives
        anInt .INT -12345    aChar .BYT 'a'  ; Multi line assembly biatches!
        .BYT 'b'

        ; Zero operands
        END
        BLK

        ; One operand
        JMP label
        LCK label
        ULK label
        TRP 0
        TRP 1
        TRP 2
        TRP 3
        TRP 4
        TRP 10
        TRP 11
        JMR R0

        ; Two operands
        BNZ R0 label
        BGT R0 label
        BLT R0 label
        BRZ R0 label
        LDA R0 label
        LDR R0 label
        STR R0 label
        LDB R0 label
        STB R0 label
        RUN R0 label
        ADI R0 123
        LDR R0 R1
        STR R0 R1
        LDB R0 R1
        STB R0 R1
        MOV R0 R1
        ADD R0 R1
        SUB R0 R1
        MUL R0 R1
        DIV R0 R1
        AND R0 R1
        OR  R0 R1
        CMP R0 R1
        
        ; Label on instruction
        label TRP 0
        "); }

        try {
            auto assembler = new Assembler(file);
            assembler.run;
            assert(assembler.getLabels.length == 3);
            assert(assembler.getFirstInstructionOffset == 6);
        } catch (Exception e) {
            e.msg.writeln;
        }
    } // End syntax check


    {
        // Begin syntax + byte code generation
        string file = "test.asm";
        scope(exit) { if (file.exists) file.remove; }
        
        { File(file, "w").write(r"
            .BYT 'a'
            .INT -123
            .BYT 'b'
            JMP main
            main TRP 0
        "); }

        try {
            auto assembler = new Assembler(file);
            assembler.run; assembler.run;
            auto memory = assembler.getMemory();
            assert(memory.readFrom!char(0) == 'a');
            assert(memory.readFrom!int(1) == -123);
            assert(memory.readFrom!char(5) == 'b');
            assert(memory.readFrom!int(6) == Opcode.JMP);

            //auto labels = assembler.getLabels;
            assert(memory.readFrom!int(10) == assembler.getLabels["main"]);
            assert(memory.readFrom!int(18) == Opcode.TRP);
            assert(memory.readFrom!int(22) == 0);

        } catch (Exception e) {
            e.msg.writeln;
        }
    } // End parsing test
    
} // End unittest