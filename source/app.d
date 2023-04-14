import std.getopt;
import std.stdio;
import std.socket;

import photon;

void server() {

}

void fileWatch() {
	
}

void main()
{
	startloop();
	spawn(() => server());
	spawn(() => fileWatch());
	runFibers();
}
