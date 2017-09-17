// Author: http://lemming.life
// Language: D
// Project: Clipboard Share
// Description: Offers a way to allow a user to share text data among computers by using a
//   USB sharing switch and a small memory location (flash drive, hdd).
//   Devices needed: http://amzn.to/2wk5MFX , http://amzn.to/2xcad4t

// Essentially:
//   When the user copies text from any source(browser, notepad, etc), the program will attempt to write
//   from clipboard to the memory location. If we switch to the other PC then the 
//   program will attempt to read from the drive and place the text in the clipboard. 
//   In this way we give limited access.

// Needed to compile: dlang, dub

// To build use: dub
// To run on a Mac/Linux: ./cshare <directory_of_drive>
// To run on Windows: cshare.exe <directory_of_drive>

import clipboard_share;

void main(string[] args) {
    if (args.length != 2) return;
    (new ClipboardShare(args[1])).monitor;
}