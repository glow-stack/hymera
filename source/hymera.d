module hymera;

import core.sys.linux.sys.inotify;

import std.getopt, std.regex, std.stdio, std.socket;

import photon, http, dinotify;

class HelloWorldProcessor : HttpProcessor {
    HttpHeader[] headers = [HttpHeader("Content-Type", "text/plain; charset=utf-8")];

    this(Socket sock){ super(sock); }
    
    override void onComplete(HttpRequest req) {
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
        spawn(() => worker(client));
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

}

void compileServer() {
	auto inotify = iNotifyTree(".", IN_CREATE | IN_DELETE);
	while (true) {
		auto events = inotify.read();
		foreach (ev; events) {
			writeln("Event: %s", ev);
		}
	}
}

void main()
{
	startloop();
	spawn(() => server());
	spawn(() => fileWatch());
	spawn(() => compileServer());
	runFibers();
}
