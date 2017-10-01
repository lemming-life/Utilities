module convenience;

string to_s(T)(T n) {
    import std.conv : to;
    return to!string(n);
}

int to_i(T)(T n) {
    import std.conv : to;
    return to!int(n);
}

E to_member(E)(string text) {
    import std.conv : to;
    import std.traits : EnumMembers;
    E e;
    foreach(member; EnumMembers!E) {
        if (to!string(member) == text) {
            e = member;
            break;
        }
    }
    return e;
}


E[] to_array(E)() {
    import std.traits : EnumMembers;
    E[] es;
    foreach(member; EnumMembers!E) {
        es ~= member;
    }
    return es;
}

string[] to_array_values(E)() {
    import std.traits : EnumMembers;
    string[] values;
    foreach(member; EnumMembers!E) {
        string value = member;
        values ~= value;
    }
    return values;
} 

void writeTo(T)(byte[] memory, T value, int offset) {
    debug {
        import std.stdio : writeln;
        ("Writing memory at " ~ offset.to_s ~ " value of " ~ value.to_s).writeln;
    }
    *cast(T*)(&memory[offset]) = value;
}

T readFrom(T)(byte[] memory, int offset) {
    T value = *cast(T*)(&memory[offset]);
    debug { 
        import std.stdio : writeln;
        ("Reading memory at " ~ offset.to_s ~ " value is " ~ value.to_s).writeln;
    }

    return value;
}


unittest {
    debug {
        import std.stdio : writeln;
        "\n\nBEGINNING convenience.d unittest".writeln;
    }

    assert(123.to_s == "123");
    assert("-123".to_i == -123);

    enum Color : string { RED = "Red",  GREEN = "Green" }
    assert(to_member!Color("Red") == Color.RED);
    assert(to_array!Color() == [Color.RED, Color.GREEN]);
    assert(to_array_values!Color() == ["Red", "Green"]);

    byte[] memory = new byte[100];
    memory.writeTo('a', 0);
    memory.writeTo(3, 1);
    assert(memory.readFrom!char(0) == 'a');
    assert(memory.readFrom!int(1) == 3);
}