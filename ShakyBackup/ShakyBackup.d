/* Author: http://lemming.life
Project: ShakyBackup.d
Date: June 26, 2017
Language: D
Compile tool: rdmd from http://dlang.org
Details:
 - Copy files from source drive to destination drive.
 - If modified-times of source is greater than destination files then override.
 - Remove files found in destination that are not in source.
 - Keeps log as backupLog.txt

Note:
 - Recommend using some kind of scheduler (in Windows use Task Scheduler)

To compile:
rdmd --build-only ShakyBackup.d

To run (on Windows), where D: and E: are the source and destination drives, respectively.
ShakyBackup.exe D: E:
*/

import std.algorithm: each, map;
import std.array;
import std.conv: to;
import std.datetime;
import std.exception; 
import std.file: append, copy, dirEntries, DirEntry, exists, isDir, isFile, mkdir, remove, rename, rmdirRecurse, SpanMode, timeLastModified;
import std.range: retro;
import std.stdio: File, write, writeln;

void main(string[] args) {
    if (args.length != 3) return;
    
    string[] messages;
    int copyCount, removedFileCount, removedFolderCount;
    const int MAX_MESSAGES = 99;

    // Begin writing the log.
    auto backupLogName = "backupLogTemp.txt";
    auto startTime = (to!DateTime(Clock.currTime)).toSimpleString;
    
    // Functions for saving log
    void logMessages() { messages.each!(message => append(backupLogName, message)); }
    void logOffloadMessages() { if (messages.length > MAX_MESSAGES) { logMessages; } }

    // Finish writing the log
    scope(exit) {
        // Save remaining messages
        logMessages;
        append(backupLogName, "\n - Messages:");
        append(backupLogName, "\n - Removed folders count: " ~ to!string(removedFolderCount));
        append(backupLogName, "\n - Removed files count: " ~ to!string(removedFileCount));
        append(backupLogName, "\n - Files/folders copied: " ~ to!string(copyCount));
        append(backupLogName, "\n - Completed: " ~ (to!DateTime(Clock.currTime)).toSimpleString);
        append(backupLogName, "\nBACKUP START: " ~ startTime);

        // Begin saving the final log
        string backupLogFinalName = "backupLogFinal.txt";
        auto backupLogFinal = File(backupLogFinalName, "w");

        // Reverse the order of this run's log, and save it to the final log file.
        // Read the file by line, convert the line to a string, add each line to an array,
        // , reverse the array, store each entry in the array to backupLogFinal
        // and close the file. :)
        if (backupLogName.exists) {
            with ( File(backupLogName) ) {
                byLine.map!(to!string).array.retro.each!(line => backupLogFinal.writeln(line));
                close;
            }
        }
        
        // Save the previous log
        string backupLogExistingName = "backupLog.txt";
        if (backupLogExistingName.exists) {
            with( File(backupLogExistingName) ) {
                byLine.each!(line => backupLogFinal.writeln(line));
                close;
            }
            backupLogFinal.writeln("\n");
        }

        // Cleanup
        backupLogFinal.close;
        remove(backupLogName);
        rename(backupLogFinalName, backupLogExistingName);

    } // End scope(exit)

    // For readability
    string sourceDrive = args[1];
    string destinationDrive = args[2];

    // Copy files from source drive to destination drive.
    // - If modified-times of source is greater than destination files then override.
    foreach(sourceFile; dirEntries(sourceDrive, SpanMode.breadth)) {
        string destinationFile = destinationDrive ~ sourceFile[destinationDrive.length .. $];
        try {
            if (destinationFile.exists) {
                if (sourceFile.isFile && timeLastModified(sourceFile) > timeLastModified(destinationFile)) {
                    remove(destinationFile);
                    copy(sourceFile, destinationFile);
                    ++copyCount;
                }
            } else {
                if (sourceFile.isFile) {
                    copy(sourceFile, destinationFile);
                } else {
                    destinationFile.mkdir;
                }
                ++copyCount;
            }
        } catch (Exception e) {
            logOffloadMessages;
            messages ~= "\n - Failed to copy: " ~ sourceFile;
        }
    } // End copy files section

    // Remove files found in destination that are not in source.
    foreach(destinationFile; dirEntries(destinationDrive, SpanMode.breadth)) {
        string sourceFile = sourceDrive ~ destinationFile[sourceDrive.length .. $];
        try {
            if ( !sourceFile.exists ) {
                if (destinationFile.isFile) {
                    remove(destinationFile);
                    ++removedFileCount;
                } else {
                    rmdirRecurse(destinationFile);
                    ++removedFolderCount;
                }
            }
        } catch (Exception e) {
            logOffloadMessages;
            messages ~= "\n - Failed to remove: " ~ sourceFile;
        }
    } // End remove files section

} // End main()