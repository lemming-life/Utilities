module convenience;

import std.conv : to;
import std.traits : EnumMembers;

import enums;


string to_s(T)(T n) {
    return to!string(n);
}

E to_member(E)(string text) {
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
    E[] es;
    foreach(member; EnumMembers!E) {
        es ~= member;
    }
    return es;
}

string[] to_array_values(E)() {
    string[] values;
    foreach(member; EnumMembers!E) {
        string value = member;
        values ~= value;
    }
    return values;
} 

unittest {
    assert(123.to_s == "123");

    enum Color : string { RED = "Red",  GREEN = "Green" }
    assert(to_member!Color("Red") == Color.RED);
    assert(to_array!Color() == [Color.RED, Color.GREEN]);
    assert(to_array_values!Color() == ["Red", "Green"]);
}