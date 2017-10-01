// Author: http://lemming.life
// Title: Watcher
// Description: Watches source code files for changes ,
//              and runs compile/execute tools on those source files.
//              It should help speed up test driven development.
// Supports: D files with unittest
//           SML of New Jersey files
//           Golang
//           Could be extended to cover Java, Go, and other languages by adding
//           a class that covers the specific needs of that language.

// Build: rdmd --build-only watcher

// How to use: ./watcher <directory_to_monitor>

// Example usage: ./watcher Test
// Now modify and save the test.d or file.sml file.

import core.thread, std.datetime, std.file, std.path, std.process, std.string, std.stdio;

void main(string[] args) {
    if (args.length != 2) { "Invalid argument count.".writeln; return; }
    (new Watcher(args[1])).run();
}


enum Extension : string { D = ".d", SML = ".sml", GO = ".go" }

class Watcher {
    public:

    // Constructor
    this(string originPath) {
        this.originPath = originPath;
        executeMap[Extension.D] = new WatcherD();
        executeMap[Extension.SML] = new WatcherSML();
        executeMap[Extension.GO] = new WatcherGolang();
    }

    // Monitors the originPath
    void run() {
        ("WATCHER | Monitoring " ~ originPath.absolutePath).writeln;

        while(true) {
            monitor(originPath);
            clean();
            Thread.sleep( dur!("seconds")(1));
        }
    }

    private:

    WatcherBehavior[Extension] executeMap;
    SysTime[string] fileDateTimeStamp;
    string originPath;

    void monitor(string path) {
        if (!path.exists) { "Not valid path.".writeln; return; }

        foreach(DirEntry entry; dirEntries(path, SpanMode.depth)) {
            if (entry.name in fileDateTimeStamp) {
                if (entry.timeLastModified > fileDateTimeStamp[entry.name]) {
                    writeln("WATCHER | File modified " ~ entry.name);
                    fileDateTimeStamp[entry.name] = entry.timeLastModified;
                    execute(entry.name);
                }
            } else {
                writeln("WATCHER | Adding " ~ entry.name);
                fileDateTimeStamp[entry.name] = entry.timeLastModified;
            }

            if (entry.isDir) monitor(entry.name);
        }
    }

    void execute(string name) {
        foreach(k, v; executeMap) {
            if (name.lastIndexOf(k) == name.length - k.length) {
                executeMap[k].preRun(name);
                executeMap[k].run();
                executeMap[k].postRun();
            }
        }
    }

    void clean() {
        foreach(k, v; fileDateTimeStamp) {
            if (!k.exists) {
                fileDateTimeStamp.remove(k);
                writeln("WATCHER | File removed " ~ k);
            }
        }
    }

} // End class Watcher

abstract class WatcherBehavior {
    string[] params;
    string originalName;
    string currentName;

    void preRun(string originalName) {
        this.originalName = originalName;
    }

    void run() {
        wait( spawnProcess(params ~ [originalName]) );
    }

    void postRun() {
        ("WATCHER | Execution of " ~  originalName ~ " completed at " ~ Clock.currTime().toSimpleString()).writeln;
    }
}

class WatcherD : WatcherBehavior {
    override void preRun(string originalName) {
        import std.regex;
        this.originalName = originalName;
        auto text = originalName.readText;
        if ( matchFirst(text, regex("void[ \t]+main")) ) {
            params = ["rdmd"];
        } else if( matchFirst(text, regex("unittest")) ) {
            params = ["rdmd", "-unittest", "--main"];
        }
    }
}


class WatcherSML : WatcherBehavior {
    this() {
        params = ["sml"];
    }

    override void preRun(string originalName) {
        this.originalName = originalName;
        currentName = originalName[0 .. originalName.length - Extension.SML.length] ~ "_temp" ~ Extension.SML;
        copy(originalName, currentName);
        append(currentName, "OS.Process.exit(OS.Process.success);");
    }

    override void run() {
        wait( spawnProcess(params ~ [currentName]) );
    }

    override void postRun() {
        super.postRun();
        if (currentName.exists) currentName.remove;
    }
}

class WatcherGolang : WatcherBehavior {
    override void preRun(string originalName) {
        import std.regex;
        this.originalName = originalName;
        auto text = originalName.readText;

        if ( matchFirst(text, regex("func[ \t]+main")) ) {
            params = ["go", "run"];
        } else {
            params = ["go", "build"];
        }
    }
}
