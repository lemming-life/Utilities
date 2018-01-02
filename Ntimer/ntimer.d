import std.stdio;
import std.conv;
import std.process;
import std.datetime;
import std.file;

// Example:
// ./ntimer 1 1 2 1
// Plays a sound when the timer hits 1 minute, then another minute, then two minutes, then one minute, repeat.

void main(string[] args) {
  if (args.length < 2) return;
  
  //string[] sound_files = System.getFiles("/Users/jesse/sync/media/music/zedd/Clarity");
  string[] sound_files = System.getFiles("/System/Library/Sounds");

  auto next_sound = new Next!long(0, sound_files.length - 1);

  Node[] nodes = [];
  for(int i=1; i<args.length; ++i) {
    nodes ~= new Node(sound_files[next_sound.get], dur!"seconds"(to!int(args[i])));
    nodes[nodes.length - 1].next = nodes[0];
    if (nodes.length > 1) nodes[nodes.length - 2].next = nodes[nodes.length - 1];
  }

  auto next_node = new Next!long(0, nodes.length - 1);
  while(true) {
    auto i = next_node.get;
    nodes[i].run;
  }
}


class Node {
  Node next;
  Duration time;
  string sound_file;

  this(string sound_file, Duration time) {
    this.sound_file = sound_file;
    this.time = time;
  }

  void run() {
    Thread.sleep(time);
    (new PlayIt(sound_file, next.time)).start;
    time.writeln;
  }
}

import core.thread;
class PlayIt : Thread {
  import core.sys.posix.signal : SIGKILL;

  Duration time;
  Pid pid;
  string sound_file;
  this(string sound_file, Duration time){
    this.pid = spawnProcess(["afplay", sound_file]);
    this.time = time;
    super(&run);
  }

  void run(){
    this.sleep(time);
    auto result = tryWait(pid);
    if (!result.terminated)  kill(pid, SIGKILL);
  }
}

// Given a range of numbers, get the next one in the sequence.
class Next (T) {
  T min, max, current;
  
  this(T min, T max, bool inclusive = true) {
    this.min = min;
    this.max = max;
    this.current = this.min + 1;
    if (inclusive) {
      --this.min;
      ++this.max;
      --this.current;
    }
  }

  T get() {
    auto to_return  = current;
    ++current;
    if (current == max) current = min+1;
    return to_return;
  }
}

class System {
  import std.path;

	static string[] getDirectories(string path, string[] ignore = null) { return get!(isDir)(path, ignore); }
	static string[] getFiles(string path, string[] ignore = null) { return get!(isFile)(path, ignore); }

	private:

	static string[] get(alias F)(string path, string[] ignore = null) {
		import std.algorithm, std.conv, std.file;
		string[] to_return = [];

		foreach(DirEntry entry; dirEntries(path, SpanMode.shallow)) {
			if ( !F(entry.name) || (ignore !is null && ignore.canFind(entry.name.baseName)) ) continue;
			to_return ~= entry.name.to!string;
		}	

		return to_return; 
	}
}
