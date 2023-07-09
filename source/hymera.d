module hymera;

import core.sys.linux.sys.inotify;

import std.algorithm, std.conv, std.digest, std.getopt, std.format, std.string, std.regex, std.process, std.stdio, std.file, std.socket;

import photon, photon.http, dinotify;

const(char)[][] split2(const(char)[] inp, const(char)[] sep) {
    size_t p = 0;
    const(char)[][] pieces;
    for (;;) {
        if (p == inp.length) break;
        if (inp[p..$].startsWith(sep)) {
            pieces ~= inp[0..p];
            if (p + sep.length >= inp.length) break;
            inp = inp[p + sep.length .. $];
        } else {
            p++;
        }
    }
    pieces ~= inp;
    return pieces;
}

unittest {
    auto sp = split2(".a/ab", "/");
    assert(sp == [".a", "ab"]);
}

unittest {
    auto sp2 = split2("/foo/bar/", "/");
    assert(sp2 == ["", "foo", "bar", ""]);
}

class HelloWorldProcessor : HttpProcessor {
    HttpHeader[] headers = [HttpHeader("Content-Type", "text/plain; charset=utf-8")];

    this(Socket sock){ super(sock); }
    
    override void handle(HttpRequest req) {
        respondWith("Hello, %s".format(req.uri), 200, headers);
    }
}


void worker(Socket client) {
	scope processor =  new HelloWorldProcessor(client);
    processor.run();
}

void server() {
    auto files = dirEntries(".", SpanMode.breadth);
    foreach (file; files) {
        if (file.isFile) {
            writeln(file.name);
            scripts[file.name] = cast(ubyte[])read(file.name);
        }
    }
    writefln("SCRIPTS %s", scripts.length);
    
    const(char)[][const(char)[]] binds;
    foreach (k, v; scripts) {
        auto m = matchFirst(k, `(\d+.\d+.\d+.\d+):(\d+)`);
        if (m) {
            binds[m[1]] = m[2];
        }
        auto parts = split(k, "/");
        writeln(binds);
    }
    foreach (k, v; scripts) {
        if (k.endsWith(".c")) {
            try {
                spawnProcess("gcc -o %s.o %s".format(k, k));
                writefln(">>>> %s", k);
            } catch (Exception e) {
                writefln("<<<< %s", e);
            }
        }
    }
    foreach (key, value; binds) {
       Socket server = new TcpSocket();
        server.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
        server.bind(new InternetAddress(key, value.to!ushort));
        server.listen(1000);
        debug writeln("Started server");

        void processClient(Socket client) {
            go(() => worker(client));
        }

        while(true) {
            try {
                debug writeln("Waiting for server.accept()");
                Socket client = server.accept();
                debug writeln("New client accepted");
                processClient(client);
            }
            catch(Exception e) {
                writefln("Failure to accept %s", e);
            }
        }
    }
}

ubyte[][string] scripts;

void fileWatch() {
	auto inotify = iNotifyTree(".", IN_CREATE | IN_MODIFY | IN_DELETE);
	while (true) {
		auto events = inotify.read();
		foreach (ev; events) {
			writefln("Event: %s", ev);
            scripts[ev.path] = null;
		}
	}
}

void compileServer() {
	
}

void main(string[] args)
{
    bool defer;
    bool daemon;
    bool override_;
    bool kill;
    string run;
    bool trace;
    bool version_;
    int workers;
    auto help = getopt(
        args,
        "b", &defer,                // TCP_DEFER_ACCEPT
        "d", &daemon,               // Deamon mode
        "g", &override_,            // Allows setting more workers than cores
        "k", &kill,                 // Gracefully stop all running Hymera processes
        "r", &run,                  // Run script without listening on socket
        "t", &trace,                 // Store all client requests in ./trace file
        "v", &version_,             // Display Hymera's version string
        "w", &workers               // Forces a certain number of workers
    ); 

    if (help.helpWanted)
    {
        defaultGetoptPrinter("Hymera - a ployglot app server.",
        help.options);
    }
	startloop();
	go(() => server());
	go(() => fileWatch());
	go(() => compileServer());
	runFibers();
}

extern(C):

