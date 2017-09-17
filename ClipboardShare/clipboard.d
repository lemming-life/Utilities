// Author: http://lemming.life
// Language: D
// Description: A class with access to clipboard features.
// Last Updated: July 21, 2017

// For testing: rdmd -unittest -main clipboard.d
// - Expect if success: 
// - Expect if fail:  unittest failure
// - Platforms tested: Windows, OSX.

// Info:
// Linux xclip : http://linux.softpedia.com/get/Text-Editing-Processing/Others/xclip-42705.shtml
// OSX pbcopy pbpaste : https://developer.apple.com/legacy/library/documentation/Darwin/Reference/ManPages/man1/pbpaste.1.html
// Windows Clipboard : https://msdn.microsoft.com/en-us/library/windows/desktop/ms648709(v=vs.85).aspx

module clipboard;

// All platform imports
import std.conv : to;

// Import platform specific
version ( Windows ) {
    import core.sys.windows.windows;
    import core.stdc.wchar_ : wcslen;
    import core.stdc.string : memcpy;
    import std.utf : toUTF16z;

    extern ( Windows ) {
        bool OpenClipboard(void*);
        bool CloseClipboard();
        void* GetClipboardData(uint);
        bool EmptyClipboard();
        void* SetClipboardData(uint, void*);
        void* GlobalLock(void*);
        bool GlobalUnlock(void*);
        void* GlobalAlloc(uint, size_t);
    }

    const int CF_UNICODETEXT = 13;
    const uint GMEM_FIXED = 0;      // Fixed memory

} else {
    // Linux and OSX
    import std.algorithm : joiner, map;
    import std.array;
    import std.process : pipeProcess, ProcessPipes, Redirect, wait;
}

class Clipboard {
    static wstring readText() {

        version( Windows ) {
            if (!OpenClipboard(null)) { return ""w; } 
            scope(exit) { CloseClipboard(); }

            // Get the clipboard data.
            void* hData = GetClipboardData(CF_UNICODETEXT);
            wchar* bPtr = cast(wchar*) GlobalLock(hData);

            // If there is clipboard data convert it and return
            if (bPtr && wcslen(bPtr)>0) {
                wstring result = to!wstring( bPtr[0 .. wcslen(bPtr)] );
                GlobalUnlock(hData);
                return result;
            }

        } else {
            ProcessPipes pipes;
            scope(exit) { wait(pipes.pid); }

            version( linux ) {
                pipes = pipeProcess(["xclip", "-o", "-selection", "clipboard"], Redirect.stdout);
            } else version ( OSX ) {
                pipes = pipeProcess(["pbpaste"], Redirect.stdout);
            }

            auto data = pipes.stdout.byChunk(4096).joiner.array;
            if (data.length > 0) {
                auto wdata = data.map!( a=> to!wchar(a));
                return to!wstring( wdata[0 .. $] );
            }
        }

        return ""w;
    }

    static void writeText(wstring text) {
        version( Windows ) {
            if (!OpenClipboard(null)) { return; } 
            scope(exit) { CloseClipboard(); }
            EmptyClipboard();

            // Allocate global memory
            const int dataLength = (text.length + 1) * wstring.sizeof;
            void* hData = GlobalAlloc(GMEM_FIXED, dataLength);
            void* bPtr = GlobalLock(hData);

            // Copy the text to the buffer
            memcpy(bPtr, toUTF16z(text), dataLength);
            GlobalUnlock(hData);

            // Place the handle on the clipboard
            SetClipboardData(CF_UNICODETEXT, hData);  
        } else {
            ProcessPipes pipes;
            scope(exit) { wait(pipes.pid); }
            
            version( linux ) {
                pipes = pipeProcess(["xclip", "-i", "-selection", "clipboard"], Redirect.stdin);
            } else version( OSX ) {
                pipes = pipeProcess(["pbcopy"], Redirect.stdin);
            }

            with(pipes) {
                stdin.write(text);
                stdin.flush();
                stdin.close();
            }
        }
    }

    static void clear() {
        writeText(""w);
    }
}


unittest {
    auto testString = "Test String"w;
    
    Clipboard.clear();
    auto newString = Clipboard.readText();
    assert( newString.length == 0 );

    Clipboard.writeText(testString);
    assert( Clipboard.readText() == testString);
}