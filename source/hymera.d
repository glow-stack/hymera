import std.getopt;
import std.stdio;
import std.socket;

import photon;

void worker(Socket socket) {

}

void server() {

}

void fileWatch() {

}

void compileServer() {

}

void main()
{
	startloop();
	spawn(() => server());
	spawn(() => fileWatch());
	spawn(() => compileServer());
	runFibers();
}
