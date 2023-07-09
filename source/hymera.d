module hymera;

import core.sys.linux.sys.inotify, core.stdc.string, core.sys.posix.unistd;

import std.algorithm, std.conv, std.digest.sha, std.getopt, std.format, std.string, std.regex, std.process, std.stdio, std.file, std.socket;

import photon, photon.http, dinotify;

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

__gshared ubyte[][string] scripts;
__gshared string[string] scriptHashes;

void server() {
    auto files = dirEntries(".", SpanMode.breadth);
    foreach (file; files) {
        if (file.isFile) {
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
    }
    foreach (k, v; scripts) {
        if (k.endsWith(".c")) {
            try {
                writefln(">>>> %s", k);
                auto hash = sha1Of(k);
                scriptHashes[k.idup] = hash.toHexString.to!string;
                int pid = fork();
                if (pid == 0) {
                    auto p = execv("/usr/bin/clang", ["/usr/bin/clang", "-o", hash.toHexString.to!string, "-c", "-I.", "-fPIC", k.to!string]);
                    writefln(">222> %s", p);
                }
            } catch (Exception e) {
                writefln("<<<< %s", e);
            }
        }
    }
    foreach (key, value; binds) try {
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
    } catch (Exception e) {
        writefln("Exception while listening %s", e);
    }
    runFibers();
}

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

struct xbuf
{
	char *ptr;       // data buffer
	union{
	    uint   allocated; // memory allocated ('size' is an alias of 'allocated')
	    uint   size;
    }
	uint   len;       // memory used
	uint   growby;    // memory allocation increment
}

void xbuf_cat(xbuf* buf, const char* fmt, void* arg) {
    auto f = fmt[0..strlen(fmt)];
    auto m = f.format("%s", arg);
    buf.ptr[0..m.length] = m[];
}
