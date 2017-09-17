// Author: http://lemming.life
// Title: DWatcher
// Description: Watches d files for changes (modules with unittest), 
//              and runs rdmd's -unittest --main
//              It should help speed up test driven development with D.

// Build: rdmd --build-only dwatcher

// How to use: ./dwatcher <directory_to_monitor>
// Now you can add and modify .d modules.

// Example usage: ./dwatcher Test

import core.thread, std.datetime, std.file, std.path, std.process, std.string, std.stdio;

void main(string[] args) {
    if (args.length != 2) { return; }
    SysTime[string] fileDateTimeStamp;
    string[][string] executeMap;
    executeMap[".d"] = ["rdmd", "-unittest", "--main"] ;

    ("WATCHER | Monitoring " ~ args[1].absolutePath).writeln;

    while(true) {
        monitor(args[1], fileDateTimeStamp, executeMap);
        clean(fileDateTimeStamp);
        Thread.sleep( dur!("seconds")(1));
    }
}

void monitor(string path, ref SysTime[string] fileDateTimeStamp, ref string[][string] executeMap) {
    if (!path.exists) { "Not valid path.".writeln; return; }

    foreach(DirEntry entry; dirEntries(path, SpanMode.depth)) {
        if (entry.name in fileDateTimeStamp) {
            if (entry.timeLastModified > fileDateTimeStamp[entry.name]) {
                writeln("WATCHER | File modified " ~ entry.name);
                fileDateTimeStamp[entry.name] = entry.timeLastModified;
                execute(entry.name, executeMap);
            }
        } else {
            writeln("WATCHER | Adding " ~ entry.name);
            fileDateTimeStamp[entry.name] = entry.timeLastModified;
        }

        if (entry.isDir) monitor(entry.name, fileDateTimeStamp, executeMap);
    }
}

void execute(string name, ref string[][string] executeMap) {
    foreach(k, v; executeMap) {
        if (name.lastIndexOf(k) == name.length - k.length) {
            wait( spawnProcess(v ~ [name]) );
            ("WATCHER | Execution of " ~  name ~ " completed.").writeln;
        }
    }
}

void clean(ref SysTime[string] fileDateTimeStamp) {
    foreach(k, v; fileDateTimeStamp) {
        if (!k.exists) {
            fileDateTimeStamp.remove(k);
            writeln("WATCHER | File removed " ~ k);
        }
    }
}