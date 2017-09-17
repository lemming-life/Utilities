// Author: http://lemming.life
// Language: D
// Project: Clipboard Share
// Description: Offers a way to allow a user to share text data among computers by using a
//   USB sharing switch and a small memory location (flash drive, hdd).
//   Devices needed: http://amzn.to/2wk5MFX , http://amzn.to/2xcad4t

module clipboard_share;
import clipboard;

class ClipboardShare {
    import core.thread;
    import std.conv : to;
    import std.datetime : Clock, SysTime;
    import std.file : DirEntry, exists, readText;
    import std.stdio : File, writeln;

    public:

    this(string path) {
        _path = path;
        _pathFile = _path ~ "/" ~ _file;
        initialStateSetup;
    }

    void monitor() {
        while(true) {
            final switch(_state) {
            case State.READY:
                if (!_path.exists) {
                    performWaiting;
                } else {
                    if (_text != Clipboard.readText) writeToFile;
                }
                break;
            case State.WAITING:
                if (_path.exists) performReady;
                break;
            }
            Thread.sleep( dur!("seconds")(2));
        }
    }

    private:

    immutable string _file = "clip.txt";
    string _path;
    string _pathFile;
    wstring _text;
    SysTime _timeStamp;
    State _state;

    enum State { WAITING, READY }

    void initialStateSetup() {
        _path.exists ? performReady : performWaiting;
    }

    void writeToFile() {
        auto oldText = _text;
        scope(failure) { _state = State.WAITING; _text = oldText; _timeStamp = Clock.currTime; } 
        auto file = File(_pathFile, "w");
        _text = Clipboard.readText;
        file.write(_text);
        file.close;
        _timeStamp = DirEntry(_pathFile).timeLastModified;
        _state = State.READY;
    }

    void readFromFile() {
        scope(failure) { _state = State.WAITING; }
        if (DirEntry(_pathFile).timeLastModified < _timeStamp) return;
        _text = to!wstring(_pathFile.readText);
        Clipboard.writeText(_text);
        _timeStamp = DirEntry(_pathFile).timeLastModified;
        _state = State.READY;
    }

    void performReady() {
        if (_pathFile.exists) {
            readFromFile;
        } else {
            writeToFile;
        }
    }

    void performWaiting() {
        _state = State.WAITING;
    }
}

unittest {
    string path = "/tmp";
    string pathFile = path ~ "/clip.txt";
    scope(exit) { std.file.remove(pathFile); }

    auto cs = new ClipboardShare(path);
    //cs.monitor();
}