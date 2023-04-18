/// Minimalistic low-overhead wrapper for nodejs/http-parser
/// Used for benchmarks with simple server
module http.http_parser;

import std.range.primitives;
import std.uni, std.string, std.exception;

enum HTTP_REQUEST = 1;
enum HTTP_RESPONSE = 2;
enum HTTP_BOTH = 3;
enum HTTTP_MAX_HEADER_SIZE = (80*1024);

/* Flag values for http_parser.flags field */
enum flags
  { F_CHUNKED               = 1 << 0
  , F_CONNECTION_KEEP_ALIVE = 1 << 1
  , F_CONNECTION_CLOSE      = 1 << 2
  , F_CONNECTION_UPGRADE    = 1 << 3
  , F_TRAILING              = 1 << 4
  , F_UPGRADE               = 1 << 5
  , F_SKIPBODY              = 1 << 6
  , F_CONTENTLENGTH         = 1 << 7
  };

public enum HttpParserType: uint {
	request = 0,
	response = 1,
	both = 2
}

public enum HttpMethod: uint {
	DELETE = 0,
	GET = 1,
	HEAD = 2,
	POST = 3,
	PUT = 4,
	/* pathological */
	CONNECT = 5,
	OPTIONS = 6,
	TRACE = 7,
	/* WebDAV */
	COPY = 8,
	LOCK = 9,
	MKCOL = 10,
	MOVE = 11,
	PROPFIND = 12,
	PROPPATCH = 13,
	SEARCH = 14,
	UNLOCK = 15,
	BIND = 16,
	REBIND = 17,
	UNBIND = 18,
	ACL = 19,
	/* subversion */
	REPORT = 20,
	MKACTIVITY = 21,
	CHECKOUT = 22,
	MERGE = 23,
	/* upnp */
	MSEARCH = 24,
	NOTIFY = 25,
	SUBSCRIBE = 26,
	UNSUBSCRIBE = 27,
	/* RFC-5789 */
	PATCH = 28,
	PURGE = 29,
	/* CalDAV */
	MKCALENDAR = 30,
	/* RFC-2068, section 19.6.1.2 */
	LINK = 31,
	UNLINK = 32,
	/* icecast */
	SOURCE = 33,
}

enum HttpError : uint {
	OK,
	/* Parsing-related errors */
	INVALID_EOF_STATE,
	HEADER_OVERFLOW,
	CLOSED_CONNECTION,
	INVALID_VERSION,
	INVALID_STATUS,
	INVALID_METHOD,
	INVALID_URL,
	INVALID_HOST,
	INVALID_PORT,
	INVALID_PATH,
	INVALID_QUERY_STRING,
	INVALID_FRAGMENT,
	LF_EXPECTED,
	INVALID_HEADER_TOKEN,
	INVALID_CONTENT_LENGTH,
	UNEXPECTED_CONTENT_LENGTH,
	INVALID_CHUNK_SIZE,
	INVALID_CONSTANT,
	INVALID_INTERNAL_STATE,
	STRICT,
	PAUSED,
	UNKNOWN,
}


enum   UF_SCHEMA           = 0;
enum    UF_HOST             = 1;
enum UF_PORT             = 2;
enum   UF_PATH             = 3;
enum    UF_QUERY            = 4;
enum   UF_FRAGMENT         = 5;
enum   UF_USERINFO         = 6;
enum   UF_MAX              = 7;

enum ParserFields {
  method,
  url,
  status,
  port,
  query,
  fragment,
  userinfo
}

struct HttpEvent {
  ParserFields tag;
  union {
    int method;
    char[] url;
    int status;
    int port;
    char[] query;
    char[] fragment;
    char[] userinfo;
  }
}

enum HttpState {
  METHOD = 0,
  URL = 1,
  VERSION = 2,
  HEADER_START = 3,
  HEADER_CONT = 4,
  BODY = 5
}

struct Parser {
  char[] buf;
  size_t pos;
  HttpEvent event;
  bool isEmpty;
  HttpState state;

  void put(char[] bite) {
    buf ~= bite;
    while (pos < buf.length) {
      with (HttpState) switch(state) {
        case METHOD:
        import std.regex;
          auto m = matchFirst(buf[pos..$], r"(delete|get|put|...)\s+(\w+)\s+");
          isEmpty = false;
          event.tag = ParserFields.method;
          with (HttpMethod) switch(m[1]) {
            case "delete":
              event.method = DELETE;
              pos += "delete".length;
              break;
            case "get":
              event.method = GET;
              pos += "get".length;
              break;
            case "put":
              event.method = PUT;
              pos += "put".length;
              break;
            case "head":
              event.method = HEAD;
              pos += "head".length;
              break;
            case "post":
              event.method = POST;
              pos += "post".length;
              break;
            case "connect":
              event.method = CONNECT;
              pos += "connect".length;
              break;
            case "trace":
              event.method = TRACE;
              pos += "trace".length;
              break;
            /* WebDAV */
            case "copy":
              event.method = COPY;
              pos += "copy".length;
              break;
            case "lock":
              event.method = LOCK;
              pos += "lock".length;
              break;
            case "mkcol":
              event.method = MKCOL;
              pos += "mkcol".length;
              break;
            case "move":
              event.method = MOVE;
              pos += "move".length;
              break;
            case "propfind":
              event.method = PROPFIND;
              pos += "propfind".length;
              break;
            case "proppatch":
              event.method = PROPPATCH;
              pos += "proppatch".length;
              break;
            case "search":
              event.method = SEARCH;
              pos += "search".length;
              break;
            case "unlock":
              event.method = UNLOCK;
              pos += "unlock".length;
              break;
            case "acl":
              event.method = ACL;
              pos += "acl".length;
              break;
            case "bind":
              event.method = BIND;
              pos += "bind".length;
              break;
            case "rebind":
              event.method = REBIND;
              pos += "rebind".length;
              break;
            case "unbind":
              event.method = UNBIND;
              pos += "unbind".length;
              break;
            default:
              enforce(false, "Failed to parser HTTP method");
          }
          break;
        case URL:
          break;
        case VERSION:
          break;
        case HEADER_START:
          break;
        case HEADER_CONT:
          break;
        case BODY:
          break;
        default:
          assert(false);
      }
    }
  }

  void clear() {
    buf.length = 0;
    buf.assumeSafeAppend();
  }

  bool empty() const { return isEmpty; }

  void popFront() {
    isEmpty = true;
  }

  HttpEvent front() {
    return event;
  }
}

static assert(isInputRange!Parser);
static assert(isOutputRange!(Parser, char[]));
