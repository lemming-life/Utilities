module cshare;

import clipboard;

import core.thread;

class ClipboardShare {
    import std.conv : to;
    import std.stdio : File, writeln;
    import std.file : exists, readText;

    private:
        string _pathFile;

    public:
        this(string pathFile) {
            _pathFile = pathFile;
        }

        void monitor() {
            while(true) {
                
            }
        }

        bool verifyPathFile() {
            scope(failure) { ("Could not write " ~ _pathFile).writeln; }

            if (!_pathFile.exists) {
                auto file = File(_pathFile, "w");
                file.write(Clipboard.readText);
            } else {
                auto txt = _pathFile.readText;
                Clipboard.writeText(to!wstring(txt));
            }

            return _pathFile.exists;
        }



}

unittest {
    string pathFile = "/tmp/clip.txt";
    //scope(exit) { std.file.remove(pathFile); }

    auto cs = new ClipboardShare(pathFile);
    assert(cs.verifyPathFile);
    //cs.monitor();
}