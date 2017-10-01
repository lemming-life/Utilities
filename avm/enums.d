module enums;

enum TokenType {
    LABEL, DIRECTIVE, INT, CHAR, OPCODE,
    REGISTER, WS, COMMENT, EOF, INVALID,
    NONE
}

enum Opcode {
    JMP, JMR, BNZ, BGT, BLT,
    BRZ, MOV, LDA, ADD, ADI,
    SUB, MUL, DIV, AND, OR,
    CMP, TRP, RUN, END, BLK,
    LCK, ULK, STRI, LDRI, STBI,
    LDBI, STR, LDR, STB, LDB,
}

enum Register {
    R0, R10, R11, R12, R1,
    R2, R3, R4, R5, R6,
    R7, R8, R9, SP, FP,
    SL, SB, PC
}

enum Directive {
    INT, BYT
}

enum Trap : string {
    ZERO = "0", ONE = "1", TWO = "2",
    THREE = "3", FOUR = "4", TEN = "10",
    ELEVEN = "11", NINETY_NINE = "99"
}

enum Offset : int {
    BYT = 1, INT = 4, INSTR = 12
}

enum Pass {
    NILL, FIRST, SECOND
}