module token;
import enums;

struct Token {
    import std.conv : to;

    private:
    string _text;
    TokenType _type;
    uint _lineNumber;
    
    public:

    this(string text, TokenType type) {
        this._text = text;
        this._type = type;
    }

    int to_i() {
        import std.conv : to;
        int result;
        switch(_type) {
            default:                result = 0;                                 break;
            case TokenType.INT:     result = to!int(_text);                     break;
            case TokenType.CHAR:    result = to!int(to!char(_text[1 .. $-1]));  break;
        }
        return result;
    } // End to_i

    @property {
        string text() { return _text; }
        void text(string text) { _text = text; }
        TokenType type() { return _type; }
        void type(TokenType type) { _type = type; }
        uint lineNumber() { return _lineNumber; }
        void lineNumber(uint lineNumber) { _lineNumber = lineNumber; }
    }
} // End struct Token

unittest {
    assert(Token("1", TokenType.INT).to_i == 1);
    assert(Token("'a'", TokenType.CHAR).to_i == 97);
    assert(Token("'\n'", TokenType.CHAR).to_i == 10);
}