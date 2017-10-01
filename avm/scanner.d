module scanner;
import enums, token;

class Scanner {
    import std.file, std.stdio, std.string, std.regex;

    private: 
    File file;
    string line;
    uint lineCount;
    Token currentToken;

    Token readNextToken() {
        while(true) {
            if (line.length == 0 && file.eof) return Token("", TokenType.EOF);
            if (line.length == 0) { line = file.readln.strip; ++lineCount; }
            if (line.length>0) return processLine;
        }
    }

    Token processLine() {
        Token token;
        string text;

        if ( match(line, text, regex(enumToRegexString!(Directive)(".", "")))) {
            token = Token(text, TokenType.DIRECTIVE);
        } else if ( match(line, text, regex(r"^(_|[a-zA-Z])+(\w)*"))) {
            token = Token(text, TokenType.LABEL);
            string text2;
            if ( match(line, text2, regex(enumToRegexString!(Register))) && text2 == text) {
                token = Token(text, TokenType.REGISTER);
            } else if (match(line, text2, regex(enumToRegexString!(Opcode))) && text2 == text) {
                token = Token(text, TokenType.OPCODE);
            }

        } else if ( match(line, text, regex(r"^-?[0-9]+")) ) {
            token = Token(text, TokenType.INT);
        } else if ( match(line, text, regex(r"^'\\?.'")) ) {
            token = Token(text, TokenType.CHAR);
        } else if( match(line, text, regex(r"^\s") )) {
            while(match(line[1 .. $], text, regex(r"^\s") )) {
                line = line[text.length .. $];
            }
            token = Token(" ", TokenType.WS);
        } else if ( match(line, text, regex(r"^;"))) {
            token = Token(line, TokenType.COMMENT);
            line = "";
        } else {
            token = Token("", TokenType.INVALID);
        }

        if (text.length>0 && line.length>0) line = line[text.length .. $];
        token.lineNumber = lineCount;
        return token;
    }

    bool match(string line, ref string text, Regex!char reg) {
        auto results = line.matchFirst(reg);
        if (results) text = results[0];
        return results.length > 0;
    }

    string enumToRegexString(E)(string prefix = "", string postfix = "") {
        import std.traits : EnumMembers;
        import std.conv : to;

        string str = "^(";
        foreach(member; EnumMembers!E) {
            str = str ~ prefix ~ to!string(member) ~ postfix ~ "|";
        }
        return str = str[0..$-1] ~ ")";
    }


    public:

    this(string file) {
        if (file.exists) this.file = File(file);
        this.line = "";
        currentToken = Token("", TokenType.NONE);
    }

    Token token() { return currentToken; }
    Token getNextToken() { return currentToken = readNextToken(); }

} // End class Scanner


unittest {
    debug {
        import std.stdio : writeln;
        "\n\nBEGINNING scanner.d unittest".writeln;
    }

    import std.conv : to;
    import std.traits : EnumMembers;

    auto scanner = new Scanner("");
    scanner.line = "anInt .INT 32";
    assert(scanner.processLine.type == TokenType.LABEL);
    assert(scanner.processLine.type == TokenType.WS);
    assert(scanner.processLine.type == TokenType.DIRECTIVE);
    assert(scanner.processLine.type == TokenType.WS);
    assert(scanner.processLine.type == TokenType.INT);

    scanner.line = "someLabel   .BYT 'a'";
    assert(scanner.processLine.type == TokenType.LABEL);
    assert(scanner.processLine.type == TokenType.WS);
    assert(scanner.processLine.type == TokenType.DIRECTIVE);
    assert(scanner.processLine.type == TokenType.WS);
    assert(scanner.processLine.type == TokenType.CHAR);

    scanner.line = ".BYT '\\n'";
    assert(scanner.processLine.type == TokenType.DIRECTIVE);
    assert(scanner.processLine.type == TokenType.WS);
    assert(scanner.processLine.type == TokenType.CHAR);

    scanner.line = "; My comment!";
    scanner.processLine;
    assert(scanner.line == "");

    scanner.line = ".INT 12 ; My comment";
    assert(scanner.processLine.type == TokenType.DIRECTIVE);
    assert(scanner.processLine.type == TokenType.WS);
    assert(scanner.processLine.type == TokenType.INT);
    assert(scanner.processLine.type == TokenType.WS);
    assert(scanner.processLine.type == TokenType.COMMENT);
    assert(scanner.line == "");

    scanner.line = "R00 R12 _hello JMP JMP123";
    assert(scanner.processLine.type == TokenType.LABEL);
    assert(scanner.processLine.type == TokenType.WS);
    assert(scanner.processLine.type == TokenType.REGISTER);
    assert(scanner.processLine.type == TokenType.WS);
    assert(scanner.processLine.type == TokenType.LABEL);
    assert(scanner.processLine.type == TokenType.WS);
    assert(scanner.processLine.type == TokenType.OPCODE);
    
    scanner.line = "R1X";
    assert(scanner.processLine.type == TokenType.LABEL);


    // Test all opcodes
    foreach(member; EnumMembers!Opcode) {
        scanner.line = to!string(member);
        assert(scanner.processLine.type == TokenType.OPCODE);
    }

    // Test all registers
    foreach(member; EnumMembers!Register) {
        scanner.line = to!string(member);
        assert(scanner.processLine.type == TokenType.REGISTER);
    }

    // Test directives
    foreach(member; EnumMembers!Directive) {
        scanner.line = "." ~ to!string(member);
        assert(scanner.processLine.type == TokenType.DIRECTIVE);
    }

    // Fail cases
    scanner.line = "<>";
    assert(scanner.processLine.type == TokenType.INVALID);
    scanner.line = scanner.line[1 .. $];
    assert(scanner.processLine.type == TokenType.INVALID);
} // End unittest
