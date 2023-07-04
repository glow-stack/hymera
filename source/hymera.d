module hymera;

import core.sys.linux.sys.inotify;

import std.getopt, std.regex, std.stdio, std.socket;

import photon, photon.http, dinotify;

class HelloWorldProcessor : HttpProcessor {
    HttpHeader[] headers = [HttpHeader("Content-Type", "text/plain; charset=utf-8")];

    this(Socket sock){ super(sock); }
    
    override void handle(HttpRequest req) {
        respondWith("Hello, world!", 200, headers);
    }
}


void worker(Socket client) {
	scope processor =  new HelloWorldProcessor(client);
    processor.run();
}

void server() {
	Socket server = new TcpSocket();
    server.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
    server.bind(new InternetAddress("127.0.0.1", 4321));
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

void fileWatch() {
	auto inotify = iNotifyTree(".", IN_CREATE | IN_MODIFY | IN_DELETE);
	while (true) {
		auto events = inotify.read();
		foreach (ev; events) {
			writefln("Event: %s", ev);
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
