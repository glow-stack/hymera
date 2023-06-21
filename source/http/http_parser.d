/// Minimalistic low-overhead wrapper for nodejs/http-parser
/// Used for benchmarks with simple server
module http.http_parser;

import std.range.primitives;
import std.ascii, std.string, std.exception;

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
  body_,
  method,
  url,
  status,
  port,
  header,
  query,
  version_,
  fragment,
  userinfo
}

struct Header
{
  char[] key;
  char[] value;
}

struct HttpEvent {
  ParserFields tag;
  union {
    ubyte[] body_;
    int method;
    char[] url;
    int status;
    int port;
    Header header;
    char[] query;
    char[] fragment;
    char[] userinfo;
    char[] version_;
  }
}

enum HttpState {
  METHOD = 0,
  URL = 1,
  VERSION = 2,
  HEADER_START = 3,
  BODY = 4,
  END = 5
}

struct Parser {
  char[] buf;
  size_t pos;
  HttpEvent event;
  bool isEmpty = false;
  HttpState state;

  void put(char[] bite) {
    buf ~= bite;
    step();
  }

  void skipWs() {
    while (buf[pos].isWhite()) pos++;
  }

  void step() {
    with (HttpState) switch(state) {
      case METHOD:
        with (HttpMethod) 
          if (buf[pos..pos+3].toUpper() == "GET") {
            event.method = GET;
            pos += 3;
          } 
          else if (buf[pos..pos+3].toUpper() == "PUT") {
            event.method = PUT;
            pos += 3;
          }
          else if (buf[pos..pos+4].toUpper() == "POST") {
            event.method = POST;
            pos += 4;
          }
          else if (buf[pos..pos+6].toUpper() == "DELETE") {
            event.method = DELETE;
            pos += 6;
          }
        event.tag = ParserFields.method;
        state = HttpState.URL;
        break;
      case URL:
        skipWs();
        auto start = pos;
        while (pos < buf.length) {
          if (buf[pos].isAlpha() || buf[pos].isDigit())
            pos++;
          else
            break;
        }
        event.tag = ParserFields.url;
        event.url = buf[start..pos];
        state = HttpState.VERSION;
        break;
      case VERSION:
        skipWs();
        auto start = pos;
        while (pos < buf.length) {
          if (buf[pos].isWhite() || buf[pos] == '.' || buf[pos] == '/' || buf[pos].isAlpha() || buf[pos].isDigit())
            pos++;
          else
            break;
        }
        event.tag = ParserFields.version_;
        event.version_ = buf[start..pos];
        state = HttpState.HEADER_START;
        break;
      case HEADER_START:
        skipWs();
        auto start = pos;
        while (pos < buf.length) {
          if (buf[pos].isAlpha() || buf[pos].isDigit())
            pos++;
          else if (buf[pos] == ':')
            break;
          else
            enforce(false, "Unknown character in http header " ~ buf[pos..$]);
        }
        Header hdr;
        event.tag = ParserFields.header;
        hdr.key = buf[start..pos];
        pos++;
        skipWs();
        start = pos;
        while (pos < buf.length) {
          if (buf[pos].isAlpha() || buf[pos].isDigit())
            pos++;
          else
            break;
        }
        hdr.value = buf[start..pos];
        event.header = hdr;
        state = BODY;
        break;
      case BODY:
        event.body_ = cast(ubyte[])buf[pos..$];
        event.tag = ParserFields.body_;
        state = END;
        break;
      case END:
        isEmpty = true;
        break;
      default:
        assert(false);
    }
  }

  void clear() {
    buf.length = 0;
    buf.assumeSafeAppend();
  }

  bool empty() const { return isEmpty; }

  void popFront() {
    step();
  }

  HttpEvent front() {
    return event;
  }
}

static assert(isInputRange!Parser);
static assert(isOutputRange!(Parser, char[]));
