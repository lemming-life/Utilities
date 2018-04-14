/* Author: http://lemming.life
Project: ShakyBackup.d
Date: Mar 25, 2018
Language: D
Compile tool: rdmd from http://dlang.org
Details:
 - Copy files from source to destination.
 - If modified-times of source is greater than destination files then override.

Note:
 - Recommend using some kind of scheduler.

To compile:
 rdmd --build-only shakybackup.d

To run:
 ./shakybackup source destination (-backup|-cleanup|-backup-cleanup) (-stdout)

Option : does
	-backup : performs a backup from source to destination, always adds
	-cleanup : removes files from destination that are not in source
	-backup-cleanup : performs a backup and then a cleanup
	-stdout : enables standard out
*/

void main(string[] app_args) {
	string[] args = app_args[0 .. $];
	import std.algorithm : remove;
	try {
		scope(exit) { Logger.append("Finished shaky backup", true); }
		
		auto option = "-backup";
		auto quit = true;
		do {
			auto arg_count = args.length;
			quit = true;

			foreach(i, arg; args) {
				if (arg != "-stdout") continue;
				Logger.enable_stdout;
				args = args[0 .. i] ~ args[i+1 .. $];
				break;
			}

			foreach(i, arg; args) {
				if (arg == "-backup" || arg == "-cleanup" || arg == "-backup-cleanup") {
					option = arg;
					args = args[0 .. i] ~ args[i+1 .. $];
					break;
				}
			}

			if (args.length != arg_count) {
				arg_count = args.length;
				quit = false;
			}

			if (quit) break;
		} while(true);

		Logger.append("Begin shaky backup");

		if ( Inspect.invalid_argument_count(args.length, 3) ) return;
		auto source = args[1];
		auto destination = args[2];
		if (Inspect.invalid_directories([source, destination])) return;

		auto backup = new Backup(source, destination);
		switch(option) {
			case "-backup": 
				backup.backup;
				break;
			case "-cleanup":
				backup.cleanup;
				break;
			case "-backup-cleanup":
				backup.backup;
				backup.cleanup;
				break;
			default:
				backup.backup;
				break;
		}

	} catch (Exception e) {
		Logger.append("Could not perform operation.");
	}
} // end main

class Logger {
	import std.stdio;
	static string[] messages = [];
	static bool stdout_state = false;

	static void enable_stdout() {
		stdout_state = true;
	}

	static void toggle_stdout() {
		stdout_state = !stdout_state;
	}

	static void append(string new_message, bool finalize = false) {
		import std.file : append;
		import std.algorithm : each;
		import std.datetime;

		try {
			auto message = Clock.currTime(UTC()).toISOExtString[0 .. 19] ~ " : " ~ new_message ~ "\n";
			if (stdout_state) message.write;
			messages ~= [message];
			
			if (messages.length > 256 || finalize) {
				auto all_messages = "";
				messages.each!(msg => all_messages = all_messages ~ msg);
				"log.log".append(all_messages);
				messages = [];
			}
		} catch (Exception e) {
			import std.stdio : writeln;
			"Could not append log.".writeln;
		}
	}
} // end Logger

class Inspect {
	enum Msg {
		invalid_argument_count = `Invalid argument count.`,
		does_not_exist = `Does not exist.`, 
		
	}

	static bool invalid_directories(string[] values) {
		import std.file : exists, isDir;
		foreach(value; values) {
			auto result = value.exists && value.isDir;
			if (fails(result, value, Msg.does_not_exist)) return true;
		}
		return false;
	}

	static bool invalid_files(string[] values) {
		import std.file : exists, isFile;
		foreach(value; values) {
			auto result = value.exists && value.isFile;
			if (fails(result, value, Msg.does_not_exist)) return true;
		}
		return false;
	}

	static bool invalid_argument_count(ulong value, ulong expected) {
		auto result = value >= expected; 
		return fails(result, value, Msg.invalid_argument_count);
	}

	static bool fails(T)(bool result, T value, string msg = "Failed.") {
		import std.conv : to;
		if (!result) Logger.append(msg ~ " | " ~ value.to!string);
		return !result;
	}
} // end Inspect


class Backup {
	string source, destination, shaky_dir;
	string[] ignore_names = [".fseventsd", ".Spotlight-V100", ".TemporaryItems", ".Trashes", ".build", ".DS_Store"];

	this(string source, string destination) {
		this.source = fix_dir(source); 
		this.destination = fix_dir(destination);
		this.shaky_dir = this.destination ~ "shaky/";
	}

	void cleanup() {
		// Remove files found in destination that are not in source.
		import std.file;
		import std.stdio;

		foreach(destination_file; dirEntries(destination, SpanMode.depth)) {
			if (skip(destination_file.name)) continue;

			string source_file = source ~ destination_file[destination.length .. $];

			try {
				if ( !source_file.exists ) {
					if (destination_file.isFile) {
						remove(destination_file);
					} else if(destination_file.isDir) {
						rmdirRecurse(destination_file);
					}
					Logger.append("Removing " ~ destination_file);
				}
			} catch (Exception e) {
				Logger.append("Failed to remove " ~ source_file);
			}
		} // End remove files section
	}

	void backup() {
		import std.path : dirName;
		import std.file;
		import std.stdio;
		import std.array : replace;

		foreach(source_file; dirEntries(source, SpanMode.breadth)) {
			if (skip(source_file.name)) continue;

			string source_name = source_file[source.length .. $];
			string destination_file = destination ~ source_name;

			try {
				if (destination_file.exists) {
					if (source_file.isFile && timeLastModified(source_file) > timeLastModified(destination_file)) {
						// save the older version 
						auto backup_file = shaky_dir ~ timeLastModified(destination_file).toISOExtString.replace(":", "-").replace(".", "-") ~ "/" ~ destination_file[destination.length .. $]; 
						mkdirRecurse(backup_file.dirName);
						copy(destination_file, backup_file, PreserveAttributes.yes);
						setTimes(backup_file, destination_file.timeLastModified, destination_file.timeLastModified);
						
						Logger.append("Storing " ~ backup_file);
						
						// override
						copy(source_file, destination_file, PreserveAttributes.yes);
						setTimes(destination_file, source_file.timeLastModified, source_file.timeLastModified);
					}
				} else {
					if (source_file.isDir) {
						Logger.append("Creating " ~ destination_file);
						destination_file.mkdir;
					} else {
						Logger.append("Copying new " ~ destination_file);
						copy(source_file, destination_file, PreserveAttributes.yes);
						setTimes(destination_file, source_file.timeLastModified, source_file.timeLastModified);
					}
				}
			} catch (Exception e) {
				Logger.append("Failed to copy " ~ source_file);
			}
		} // End copy files section
	}

	private:	

	bool skip(string name) {
		import std.string : indexOf;
			foreach(ignore_name; ignore_names) {
				if (name.indexOf(ignore_name) > -1) return true;
			}
			return false;
	}

	string fix_dir(string dir) {
		return dir[$-1] == '/' ? dir : dir ~ '/';
	}
} // end Backup