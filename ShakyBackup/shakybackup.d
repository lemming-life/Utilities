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
 ./shakybackup source destination (backup|cleanup|backup_cleanup)

Option : does
	backup : performs a backup from source to destination, always adds
	cleanup : removes files from destination that are not in source
	backup_cleanup : performs a backup and then a cleanup
*/

void main(string[] args) {
	try {
		scope(exit) { Logger.append("Finished", true); }
		import std.stdio;

		Logger.append("Begin");
		if ( Inspect.invalid_argument_count(args.length, 4) ) return;

		auto source = args[1];
		auto destination = args[2];
		if (Inspect.invalid_directories([source, destination])) return;


		"Starting backup...".writeln;
		auto backup = new Backup(source, destination);
		auto option = args[3];
		switch(option) {
			case "backup": 
				backup.backup;
				break;
			case "cleanup":
				backup.cleanup;
				break;
			case "backup_clean":
				backup.backup;
				backup.cleanup;
				break;
			default:
				backup.backup;
				break;
		}
		"Finished backup...".writeln;

	} catch (Exception e) {
		import std.stdio : writeln;
		"Could not perform operation.".writeln;
	}
} // end main

class Logger {
	static string[] messages = [];

	static void append(string message, bool finalize = false) {
		import std.file : append;
		import std.algorithm : each;
		import std.datetime;

		try {
			messages ~= [Clock.currTime(UTC()).toISOExtString[0 .. 19] ~ " : " ~ message ~ "\n"];
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
		auto result = value == expected; 
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

		foreach(source_file; dirEntries(source, SpanMode.breadth)) {
			if (skip(source_file.name)) continue;

			string source_name = source_file[source.length .. $];
			string destination_file = destination ~ source_name;

			try {
				if (destination_file.exists) {
					if (source_file.isFile && timeLastModified(source_file) > timeLastModified(destination_file)) {
						// save the older version 
						auto backup_file = shaky_dir ~ timeLastModified(destination_file).toSimpleString ~ "/" ~ destination_file[destination.length .. $]; 
						mkdirRecurse(backup_file.dirName);
						copy(destination_file, backup_file, PreserveAttributes.yes);
						setTimes(backup_file, destination_file.timeLastModified, destination_file.timeLastModified);
						
						// override
						copy(source_file, destination_file, PreserveAttributes.yes);
						setTimes(destination_file, source_file.timeLastModified, source_file.timeLastModified);
					}
				} else {
					if (source_file.isDir) {
						destination_file.mkdir;
					} else {
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