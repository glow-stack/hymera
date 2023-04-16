/// Minimalistic low-overhead wrapper for nodejs/http-parser
/// Used for benchmarks with simple server
module http.http_parser;
private:

import std.range.primitives;
import core.stdc.string;

alias http_data_cb =  extern(C) int function (http_parser*, const ubyte *at, size_t length);
alias http_cb = extern(C) int function (http_parser*);

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
	/* Callback-related errors */
	CB_message_begin,
	CB_url,
	CB_header_field,
	CB_header_value,
	CB_headers_complete,
	CB_body,
	CB_message_complete,
	CB_status,
	CB_chunk_header,
	CB_chunk_complete,
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
};

alias http_errno = int;

alias http_parser_url = char*;

struct http_parser {
  /** PRIVATE **/
  uint state; 		   // bitfield
  uint nread;          /* # bytes read in various scenarios */
  ulong content_length; /* # bytes in body (0 if no Content-Length header) */

  /** READ-ONLY **/
  ushort http_major;
  ushort http_minor;
  // bitfield
  uint status_code_method_http_errono_upgrade;
  /** PUBLIC **/
  void *data; /* A pointer to get hook to the "connection" or "socket" object */
}

struct http_parser_settings {
  http_cb      on_message_begin;
  http_data_cb on_url;
  http_data_cb on_status;
  http_data_cb on_header_field;
  http_data_cb on_header_value;
  http_cb      on_headers_complete;
  http_data_cb on_body;
  http_cb      on_message_complete;
  /* When on_chunk_header is called, the current chunk length is stored
   * in parser.content_length.
   */
  http_cb      on_chunk_header;
  http_cb      on_chunk_complete;
};

extern(C) pure @nogc nothrow void http_parser_init(http_parser *parser, HttpParserType type);

extern(C) pure @nogc nothrow int http_should_keep_alive(const http_parser *parser);

/* Return a string description of the given error */
extern(C) pure @nogc nothrow immutable(char)* http_errno_description(HttpError err);

/* Checks if this is the final chunk of the body. */
extern(C) pure @nogc nothrow int http_body_is_final(const http_parser *parser);

/* Executes the parser. Returns number of parsed bytes. Sets
* `parser.http_errno` on error. */
extern(C) pure @nogc nothrow size_t http_parser_execute(
	http_parser *parser,
	const http_parser_settings *settings,
	const ubyte *data,
	size_t len
);

extern (C) uint http_parser_flags(const http_parser* parser);

// =========== Ported code =============

/* Copyright Joyent, Inc. and other Node contributors.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */



/* Tokens as defined by rfc 2616. Also lowercases them.
 *        token       = 1*<any CHAR except CTLs or separators>
 *     separators     = "(" | ")" | "<" | ">" | "@"
 *                    | "," | ";" | ":" | "\" | <">
 *                    | "/" | "[" | "]" | "?" | "="
 *                    | "{" | "}" | SP | HT
 */
static const char[256] tokens = [
/*   0 nul    1 soh    2 stx    3 etx    4 eot    5 enq    6 ack    7 bel  */
        0,       0,       0,       0,       0,       0,       0,       0,
/*   8 bs     9 ht    10 nl    11 vt    12 np    13 cr    14 so    15 si   */
        0,       0,       0,       0,       0,       0,       0,       0,
/*  16 dle   17 dc1   18 dc2   19 dc3   20 dc4   21 nak   22 syn   23 etb */
        0,       0,       0,       0,       0,       0,       0,       0,
/*  24 can   25 em    26 sub   27 esc   28 fs    29 gs    30 rs    31 us  */
        0,       0,       0,       0,       0,       0,       0,       0,
/*  32 sp    33  !    34  "    35  #    36  $    37  %    38  &    39  '  */
        0,      '!',      0,      '#',     '$',     '%',     '&',    '\'',
/*  40  (    41  )    42  *    43  +    44  ,    45  -    46  .    47  /  */
        0,       0,      '*',     '+',      0,      '-',     '.',      0,
/*  48  0    49  1    50  2    51  3    52  4    53  5    54  6    55  7  */
       '0',     '1',     '2',     '3',     '4',     '5',     '6',     '7',
/*  56  8    57  9    58  :    59  ;    60  <    61  =    62  >    63  ?  */
       '8',     '9',      0,       0,       0,       0,       0,       0,
/*  64  @    65  A    66  B    67  C    68  D    69  E    70  F    71  G  */
        0,      'a',     'b',     'c',     'd',     'e',     'f',     'g',
/*  72  H    73  I    74  J    75  K    76  L    77  M    78  N    79  O  */
       'h',     'i',     'j',     'k',     'l',     'm',     'n',     'o',
/*  80  P    81  Q    82  R    83  S    84  T    85  U    86  V    87  W  */
       'p',     'q',     'r',     's',     't',     'u',     'v',     'w',
/*  88  X    89  Y    90  Z    91  [    92  \    93  ]    94  ^    95  _  */
       'x',     'y',     'z',      0,       0,       0,      '^',     '_',
/*  96  `    97  a    98  b    99  c   100  d   101  e   102  f   103  g  */
       '`',     'a',     'b',     'c',     'd',     'e',     'f',     'g',
/* 104  h   105  i   106  j   107  k   108  l   109  m   110  n   111  o  */
       'h',     'i',     'j',     'k',     'l',     'm',     'n',     'o',
/* 112  p   113  q   114  r   115  s   116  t   117  u   118  v   119  w  */
       'p',     'q',     'r',     's',     't',     'u',     'v',     'w',
/* 120  x   121  y   122  z   123  {   124  |   125  }   126  ~   127 del */
       'x',     'y',     'z',      0,      '|',      0,      '~',       0 ];


static const byte[256] unhex =
  [-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
  , 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,-1,-1,-1,-1,-1,-1
  ,-1,10,11,12,13,14,15,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ,-1,10,11,12,13,14,15,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ];

static const ubyte[32] normal_url_char = [
/*   0 nul    1 soh    2 stx    3 etx    4 eot    5 enq    6 ack    7 bel  */
        0    |   0    |   0    |   0    |   0    |   0    |   0    |   0,
/*   8 bs     9 ht    10 nl    11 vt    12 np    13 cr    14 so    15 si   */
        0    |   2   |   0    |   0    |   16  |   0    |   0    |   0,
/*  16 dle   17 dc1   18 dc2   19 dc3   20 dc4   21 nak   22 syn   23 etb */
        0    |   0    |   0    |   0    |   0    |   0    |   0    |   0,
/*  24 can   25 em    26 sub   27 esc   28 fs    29 gs    30 rs    31 us  */
        0    |   0    |   0    |   0    |   0    |   0    |   0    |   0,
/*  32 sp    33  !    34  "    35  #    36  $    37  %    38  &    39  '  */
        0    |   2    |   4    |   0    |   16   |   32   |   64   |  128,
/*  40  (    41  )    42  *    43  +    44  ,    45  -    46  .    47  /  */
        1    |   2    |   4    |   8    |   16   |   32   |   64   |  128,
/*  48  0    49  1    50  2    51  3    52  4    53  5    54  6    55  7  */
        1    |   2    |   4    |   8    |   16   |   32   |   64   |  128,
/*  56  8    57  9    58  :    59  ;    60  <    61  =    62  >    63  ?  */
        1    |   2    |   4    |   8    |   16   |   32   |   64   |   0,
/*  64  @    65  A    66  B    67  C    68  D    69  E    70  F    71  G  */
        1    |   2    |   4    |   8    |   16   |   32   |   64   |  128,
/*  72  H    73  I    74  J    75  K    76  L    77  M    78  N    79  O  */
        1    |   2    |   4    |   8    |   16   |   32   |   64   |  128,
/*  80  P    81  Q    82  R    83  S    84  T    85  U    86  V    87  W  */
        1    |   2    |   4    |   8    |   16   |   32   |   64   |  128,
/*  88  X    89  Y    90  Z    91  [    92  \    93  ]    94  ^    95  _  */
        1    |   2    |   4    |   8    |   16   |   32   |   64   |  128,
/*  96  `    97  a    98  b    99  c   100  d   101  e   102  f   103  g  */
        1    |   2    |   4    |   8    |   16   |   32   |   64   |  128,
/* 104  h   105  i   106  j   107  k   108  l   109  m   110  n   111  o  */
        1    |   2    |   4    |   8    |   16   |   32   |   64   |  128,
/* 112  p   113  q   114  r   115  s   116  t   117  u   118  v   119  w  */
        1    |   2    |   4    |   8    |   16   |   32   |   64   |  128,
/* 120  x   121  y   122  z   123  {   124  |   125  }   126  ~   127 del */
        1    |   2    |   4    |   8    |   16   |   32   |   64   |   0, ];

enum state
  { s_dead = 1 /* important that this is > 0 */

  , s_start_req_or_res
  , s_res_or_resp_H
  , s_start_res
  , s_res_H
  , s_res_HT
  , s_res_HTT
  , s_res_HTTP
  , s_res_http_major
  , s_res_http_dot
  , s_res_http_minor
  , s_res_http_end
  , s_res_first_status_code
  , s_res_status_code
  , s_res_status_start
  , s_res_status
  , s_res_line_almost_done

  , s_start_req

  , s_req_method
  , s_req_spaces_before_url
  , s_req_schema
  , s_req_schema_slash
  , s_req_schema_slash_slash
  , s_req_server_start
  , s_req_server
  , s_req_server_with_at
  , s_req_path
  , s_req_query_string_start
  , s_req_query_string
  , s_req_fragment_start
  , s_req_fragment
  , s_req_http_start
  , s_req_http_H
  , s_req_http_HT
  , s_req_http_HTT
  , s_req_http_HTTP
  , s_req_http_major
  , s_req_http_dot
  , s_req_http_minor
  , s_req_http_end
  , s_req_line_almost_done

  , s_header_field_start
  , s_header_field
  , s_header_value_discard_ws
  , s_header_value_discard_ws_almost_done
  , s_header_value_discard_lws
  , s_header_value_start
  , s_header_value
  , s_header_value_lws

  , s_header_almost_done

  , s_chunk_size_start
  , s_chunk_size
  , s_chunk_parameters
  , s_chunk_size_almost_done

  , s_headers_almost_done
  , s_headers_done

  /* Important: 's_headers_done' must be the last 'header' state. All
   * states beyond this must be 'body' states. It is used for overflow
   * checking. See the PARSING_HEADER() macro.
   */

  , s_chunk_data
  , s_chunk_data_almost_done
  , s_chunk_data_done

  , s_body_identity
  , s_body_identity_eof

  , s_message_done
  };

enum header_states
  { h_general = 0
  , h_C
  , h_CO
  , h_CON

  , h_matching_connection
  , h_matching_proxy_connection
  , h_matching_content_length
  , h_matching_transfer_encoding
  , h_matching_upgrade

  , h_connection
  , h_content_length
  , h_content_length_num
  , h_content_length_ws
  , h_transfer_encoding
  , h_upgrade

  , h_matching_transfer_encoding_chunked
  , h_matching_connection_token_start
  , h_matching_connection_keep_alive
  , h_matching_connection_close
  , h_matching_connection_upgrade
  , h_matching_connection_token

  , h_transfer_encoding_chunked
  , h_connection_keep_alive
  , h_connection_close
  , h_connection_upgrade
  };

enum http_host_state
  {
    s_http_host_dead = 1
  , s_http_userinfo_start
  , s_http_userinfo
  , s_http_host_start
  , s_http_host_v6_start
  , s_http_host
  , s_http_host_v6
  , s_http_host_v6_end
  , s_http_host_v6_zone_start
  , s_http_host_v6_zone
  , s_http_host_port_start
  , s_http_host_port
};

/* Macros for character classes; depends on strict-mode  */
enum CR  =                '\r';
enum LF  =                '\n';

char LOWER(char c){
  return (c | 0x20);
}

bool IS_ALPHA(char c) {
  return LOWER(c) >= 'a' && LOWER(c) <= 'z';
}

bool IS_NUM(char c) {
  return c >= '0' && c <= '9';
}

bool IS_ALPHANUM(char c) {
  return IS_ALPHA(c) || IS_NUM(c);
}

bool IS_HEX(char c) {
  return IS_NUM(c) || (LOWER(c) >= 'a' && LOWER(c) <= 'f');
}

bool IS_MARK(char c)  {
  return (c) == '-' || (c) == '_' || (c) == '.' || 
    (c) == '!' || (c) == '~' || (c) == '*' || (c) == '\'' || (c) == '(' ||
  (c) == ')';
}

bool IS_USERINFO_CHAR(char c) {
  return IS_ALPHANUM(c) || IS_MARK(c) || (c) == '%' ||
  (c) == ';' || (c) == ':' || (c) == '&' || (c) == '=' || (c) == '+' ||
  (c) == '$' || (c) == ',';
}

char STRICT_TOKEN(char c)  {
  return tokens[c];
}

/**
 * Verify that a char is a valid visible (printable) US-ASCII
 * character or %x80-FF
 **/
 bool IS_HEADER_CHAR(char ch) {
  return ch == CR || ch == LF || ch == 9 || (ch > 31 && ch != 127);
 }
  

state start_state() {
  return (parser.type == HTTP_REQUEST ? s_start_req : s_start_res);
}


int http_message_needs_eof(const http_parser *parser);

/* Our URL parser.
 *
 * This is designed to be shared by http_parser_execute() for URL validation,
 * hence it has a state transition + byte-for-byte interface. In addition, it
 * is meant to be embedded in http_parser_parse_url(), which does the dirty
 * work of turning state transitions URL components for its API.
 *
 * This function should only be invoked with non-space characters. It is
 * assumed that the caller cares about (and can detect) the transition between
 * URL and non-URL states by looking for these.
 */
static state
parse_url_char(state s, const char ch)
{
  if (ch == ' ' || ch == '\r' || ch == '\n') {
    return s_dead;
  }

  switch (s) {
    case s_req_spaces_before_url:
      /* Proxied requests are followed by scheme of an absolute URI (alpha).
       * All methods except CONNECT are followed by '/' or '*'.
       */

      if (ch == '/' || ch == '*') {
        return s_req_path;
      }

      if (IS_ALPHA(ch)) {
        return s_req_schema;
      }

      break;

    case s_req_schema:
      if (IS_ALPHA(ch)) {
        return s;
      }

      if (ch == ':') {
        return s_req_schema_slash;
      }

      break;

    case s_req_schema_slash:
      if (ch == '/') {
        return s_req_schema_slash_slash;
      }

      break;

    case s_req_schema_slash_slash:
      if (ch == '/') {
        return s_req_server_start;
      }

      break;

    case s_req_server_with_at:
      if (ch == '@') {
        return s_dead;
      }

    /* FALLTHROUGH */
    case s_req_server_start:
    case s_req_server:
      if (ch == '/') {
        return s_req_path;
      }

      if (ch == '?') {
        return s_req_query_string_start;
      }

      if (ch == '@') {
        return s_req_server_with_at;
      }

      if (IS_USERINFO_CHAR(ch) || ch == '[' || ch == ']') {
        return s_req_server;
      }

      break;

    case s_req_path:
      if (IS_URL_CHAR(ch)) {
        return s;
      }

      switch (ch) {
        case '?':
          return s_req_query_string_start;

        case '#':
          return s_req_fragment_start;
      }

      break;

    case s_req_query_string_start:
    case s_req_query_string:
      if (IS_URL_CHAR(ch)) {
        return s_req_query_string;
      }

      switch (ch) {
        case '?':
          /* allow extra '?' in query string */
          return s_req_query_string;

        case '#':
          return s_req_fragment_start;
      }

      break;

    case s_req_fragment_start:
      if (IS_URL_CHAR(ch)) {
        return s_req_fragment;
      }

      switch (ch) {
        case '?':
          return s_req_fragment;

        case '#':
          return s;
      }

      break;

    case s_req_fragment:
      if (IS_URL_CHAR(ch)) {
        return s;
      }

      switch (ch) {
        case '?':
        case '#':
          return s;
      }

      break;

    default:
      break;
  }

  /* We should never fall out of the switch above unless there's an error */
  return s_dead;
}

size_t http_parser_execute (http_parser *parser,
                            const http_parser_settings *settings,
                            const char *data,
                            size_t len)
{
  char c, ch;
  int8_t unhex_val;
  const char *p = data;
  const char *header_field_mark = 0;
  const char *header_value_mark = 0;
  const char *url_mark = 0;
  const char *body_mark = 0;
  const char *status_mark = 0;
  state p_state = cast(state) parser.state;
  const uint lenient = parser.lenient_http_headers;

  /* We're in an error state. Don't bother doing anything. */
  if (HTTP_PARSER_ERRNO(parser) != HPE_OK) {
    return 0;
  }

  if (len == 0) {
    switch (CURRENT_STATE()) {
      case s_body_identity_eof:
        /* Use of CALLBACK_NOTIFY() here would erroneously return 1 byte read if
         * we got paused.
         */
        CALLBACK_NOTIFY_NOADVANCE(message_complete);
        return 0;

      case s_dead:
      case s_start_req_or_res:
      case s_start_res:
      case s_start_req:
        return 0;

      default:
        SET_ERRNO(HPE_INVALID_EOF_STATE);
        return 1;
    }
  }


  if (CURRENT_STATE() == s_header_field)
    header_field_mark = data;
  if (CURRENT_STATE() == s_header_value)
    header_value_mark = data;
  switch (CURRENT_STATE()) {
  case s_req_path:
  case s_req_schema:
  case s_req_schema_slash:
  case s_req_schema_slash_slash:
  case s_req_server_start:
  case s_req_server:
  case s_req_server_with_at:
  case s_req_query_string_start:
  case s_req_query_string:
  case s_req_fragment_start:
  case s_req_fragment:
    url_mark = data;
    break;
  case s_res_status:
    status_mark = data;
    break;
  default:
    break;
  }

  for (p=data; p != data + len; p++) {
    ch = *p;

    if (PARSING_HEADER(CURRENT_STATE()))
      COUNT_HEADER_SIZE(1);

reexecute:
    switch (CURRENT_STATE()) {

      case s_dead:
        /* this state is used after a 'Connection: close' message
         * the parser will error out if it reads another message
         */
        if (LIKELY(ch == CR || ch == LF))
          break;

        SET_ERRNO(HPE_CLOSED_CONNECTION);
        goto error;

      case s_start_req_or_res:
      {
        if (ch == CR || ch == LF)
          break;
        parser.flags = 0;
        parser.content_length = ULLONG_MAX;

        if (ch == 'H') {
          UPDATE_STATE(s_res_or_resp_H);

          CALLBACK_NOTIFY(message_begin);
        } else {
          parser.type = HTTP_REQUEST;
          UPDATE_STATE(s_start_req);
          REEXECUTE();
        }

        break;
      }

      case s_res_or_resp_H:
        if (ch == 'T') {
          parser.type = HTTP_RESPONSE;
          UPDATE_STATE(s_res_HT);
        } else {
          if ((ch != 'E')) {
            SET_ERRNO(HPE_INVALID_CONSTANT);
            goto error;
          }

          parser.type = HTTP_REQUEST;
          parser.method = HTTP_HEAD;
          parser.index = 2;
          UPDATE_STATE(s_req_method);
        }
        break;

      case s_start_res:
      {
        parser.flags = 0;
        parser.content_length = ULLONG_MAX;

        switch (ch) {
          case 'H':
            UPDATE_STATE(s_res_H);
            break;

          case CR:
          case LF:
            break;

          default:
            SET_ERRNO(HPE_INVALID_CONSTANT);
            goto error;
        }

        CALLBACK_NOTIFY(message_begin);
        break;
      }

      case s_res_H:
        STRICT_CHECK(ch != 'T');
        UPDATE_STATE(s_res_HT);
        break;

      case s_res_HT:
        STRICT_CHECK(ch != 'T');
        UPDATE_STATE(s_res_HTT);
        break;

      case s_res_HTT:
        STRICT_CHECK(ch != 'P');
        UPDATE_STATE(s_res_HTTP);
        break;

      case s_res_HTTP:
        STRICT_CHECK(ch != '/');
        UPDATE_STATE(s_res_http_major);
        break;

      case s_res_http_major:
        if ((!IS_NUM(ch))) {
          SET_ERRNO(HPE_INVALID_VERSION);
          goto error;
        }

        parser.http_major = ch - '0';
        UPDATE_STATE(s_res_http_dot);
        break;

      case s_res_http_dot:
      {
        if ((ch != '.')) {
          SET_ERRNO(HPE_INVALID_VERSION);
          goto error;
        }

        UPDATE_STATE(s_res_http_minor);
        break;
      }

      case s_res_http_minor:
        if ((!IS_NUM(ch))) {
          SET_ERRNO(HPE_INVALID_VERSION);
          goto error;
        }

        parser.http_minor = ch - '0';
        UPDATE_STATE(s_res_http_end);
        break;

      case s_res_http_end:
      {
        if ((ch != ' ')) {
          SET_ERRNO(HPE_INVALID_VERSION);
          goto error;
        }

        UPDATE_STATE(s_res_first_status_code);
        break;
      }

      case s_res_first_status_code:
      {
        if (!IS_NUM(ch)) {
          if (ch == ' ') {
            break;
          }

          SET_ERRNO(HPE_INVALID_STATUS);
          goto error;
        }
        parser.status_code = ch - '0';
        UPDATE_STATE(s_res_status_code);
        break;
      }

      case s_res_status_code:
      {
        if (!IS_NUM(ch)) {
          switch (ch) {
            case ' ':
              UPDATE_STATE(s_res_status_start);
              break;
            case CR:
            case LF:
              UPDATE_STATE(s_res_status_start);
              REEXECUTE();
              break;
            default:
              SET_ERRNO(HPE_INVALID_STATUS);
              goto error;
          }
          break;
        }

        parser.status_code *= 10;
        parser.status_code += ch - '0';

        if ((parser.status_code > 999)) {
          SET_ERRNO(HPE_INVALID_STATUS);
          goto error;
        }

        break;
      }

      case s_res_status_start:
      {
        MARK(status);
        UPDATE_STATE(s_res_status);
        parser.index = 0;

        if (ch == CR || ch == LF)
          REEXECUTE();

        break;
      }

      case s_res_status:
        if (ch == CR) {
          UPDATE_STATE(s_res_line_almost_done);
          CALLBACK_DATA(status);
          break;
        }

        if (ch == LF) {
          UPDATE_STATE(s_header_field_start);
          CALLBACK_DATA(status);
          break;
        }

        break;

      case s_res_line_almost_done:
        STRICT_CHECK(ch != LF);
        UPDATE_STATE(s_header_field_start);
        break;

      case s_start_req:
      {
        if (ch == CR || ch == LF)
          break;
        parser.flags = 0;
        parser.content_length = ULLONG_MAX;

        if ((!IS_ALPHA(ch))) {
          SET_ERRNO(HPE_INVALID_METHOD);
          goto error;
        }

        parser.method = cast(HttpMethod) 0;
        parser.index = 1;
        switch (ch) {
          case 'A': parser.method = HTTP_ACL; break;
          case 'B': parser.method = HTTP_BIND; break;
          case 'C': parser.method = HTTP_CONNECT; /* or COPY, CHECKOUT */ break;
          case 'D': parser.method = HTTP_DELETE; break;
          case 'G': parser.method = HTTP_GET; break;
          case 'H': parser.method = HTTP_HEAD; break;
          case 'L': parser.method = HTTP_LOCK; /* or LINK */ break;
          case 'M': parser.method = HTTP_MKCOL; /* or MOVE, MKACTIVITY, MERGE, M-SEARCH, MKCALENDAR */ break;
          case 'N': parser.method = HTTP_NOTIFY; break;
          case 'O': parser.method = HTTP_OPTIONS; break;
          case 'P': parser.method = HTTP_POST;
            /* or PROPFIND|PROPPATCH|PUT|PATCH|PURGE */
            break;
          case 'R': parser.method = HTTP_REPORT; /* or REBIND */ break;
          case 'S': parser.method = HTTP_SUBSCRIBE; /* or SEARCH, SOURCE */ break;
          case 'T': parser.method = HTTP_TRACE; break;
          case 'U': parser.method = HTTP_UNLOCK; /* or UNSUBSCRIBE, UNBIND, UNLINK */ break;
          default:
            SET_ERRNO(HPE_INVALID_METHOD);
            goto error;
        }
        UPDATE_STATE(s_req_method);

        CALLBACK_NOTIFY(message_begin);

        break;
      }

      case s_req_method:
      {
        const char *matcher;
        if ((ch == '\0')) {
          SET_ERRNO(HPE_INVALID_METHOD);
          goto error;
        }

        matcher = method_strings[parser.method];
        if (ch == ' ' && matcher[parser.index] == '\0') {
          UPDATE_STATE(s_req_spaces_before_url);
        } else if (ch == matcher[parser.index]) {
          /* nada */
        } else if ((ch >= 'A' && ch <= 'Z') || ch == '-') {

          switch (parser.method << 16 | parser.index << 8 | ch) {
 //XX(meth, pos, ch, new_meth) 
            case (HTTP_POST << 16 | 1 << 8 | 'U'):
              parser.method = HTTP_PUT; break;
/*
            XX(POST,      1, 'A', PATCH)
            XX(POST,      1, 'R', PROPFIND)
            XX(PUT,       2, 'R', PURGE)
            XX(CONNECT,   1, 'H', CHECKOUT)
            XX(CONNECT,   2, 'P', COPY)
            XX(MKCOL,     1, 'O', MOVE)
            XX(MKCOL,     1, 'E', MERGE)
            XX(MKCOL,     1, '-', MSEARCH)
            XX(MKCOL,     2, 'A', MKACTIVITY)
            XX(MKCOL,     3, 'A', MKCALENDAR)
            XX(SUBSCRIBE, 1, 'E', SEARCH)
            XX(SUBSCRIBE, 1, 'O', SOURCE)
            XX(REPORT,    2, 'B', REBIND)
            XX(PROPFIND,  4, 'P', PROPPATCH)
            XX(LOCK,      1, 'I', LINK)
            XX(UNLOCK,    2, 'S', UNSUBSCRIBE)
            XX(UNLOCK,    2, 'B', UNBIND)
            XX(UNLOCK,    3, 'I', UNLINK)
*/
            default:
              SET_ERRNO(HPE_INVALID_METHOD);
              goto error;
          }
        } else {
          SET_ERRNO(HPE_INVALID_METHOD);
          goto error;
        }

        ++parser.index;
        break;
      }

      case s_req_spaces_before_url:
      {
        if (ch == ' ') break;

        MARK(url);
        if (parser.method == HTTP_CONNECT) {
          UPDATE_STATE(s_req_server_start);
        }

        UPDATE_STATE(parse_url_char(CURRENT_STATE(), ch));
        if ((CURRENT_STATE() == s_dead)) {
          SET_ERRNO(HPE_INVALID_URL);
          goto error;
        }

        break;
      }

      case s_req_schema:
      case s_req_schema_slash:
      case s_req_schema_slash_slash:
      case s_req_server_start:
      {
        switch (ch) {
          /* No whitespace allowed here */
          case ' ':
          case CR:
          case LF:
            SET_ERRNO(HPE_INVALID_URL);
            goto error;
          default:
            UPDATE_STATE(parse_url_char(CURRENT_STATE(), ch));
            if ((CURRENT_STATE() == s_dead)) {
              SET_ERRNO(HPE_INVALID_URL);
              goto error;
            }
        }

        break;
      }

      case s_req_server:
      case s_req_server_with_at:
      case s_req_path:
      case s_req_query_string_start:
      case s_req_query_string:
      case s_req_fragment_start:
      case s_req_fragment:
      {
        switch (ch) {
          case ' ':
            UPDATE_STATE(s_req_http_start);
            CALLBACK_DATA(url);
            break;
          case CR:
          case LF:
            parser.http_major = 0;
            parser.http_minor = 9;
            UPDATE_STATE((ch == CR) ?
              s_req_line_almost_done :
              s_header_field_start);
            CALLBACK_DATA(url);
            break;
          default:
            UPDATE_STATE(parse_url_char(CURRENT_STATE(), ch));
            if ((CURRENT_STATE() == s_dead)) {
              SET_ERRNO(HPE_INVALID_URL);
              goto error;
            }
        }
        break;
      }

      case s_req_http_start:
        switch (ch) {
          case 'H':
            UPDATE_STATE(s_req_http_H);
            break;
          case ' ':
            break;
          default:
            SET_ERRNO(HPE_INVALID_CONSTANT);
            goto error;
        }
        break;

      case s_req_http_H:
        STRICT_CHECK(ch != 'T');
        UPDATE_STATE(s_req_http_HT);
        break;

      case s_req_http_HT:
        STRICT_CHECK(ch != 'T');
        UPDATE_STATE(s_req_http_HTT);
        break;

      case s_req_http_HTT:
        STRICT_CHECK(ch != 'P');
        UPDATE_STATE(s_req_http_HTTP);
        break;

      case s_req_http_HTTP:
        STRICT_CHECK(ch != '/');
        UPDATE_STATE(s_req_http_major);
        break;

      case s_req_http_major:
        if ((!IS_NUM(ch))) {
          SET_ERRNO(HPE_INVALID_VERSION);
          goto error;
        }

        parser.http_major = ch - '0';
        UPDATE_STATE(s_req_http_dot);
        break;

      case s_req_http_dot:
      {
        if ((ch != '.')) {
          SET_ERRNO(HPE_INVALID_VERSION);
          goto error;
        }

        UPDATE_STATE(s_req_http_minor);
        break;
      }

      case s_req_http_minor:
        if ((!IS_NUM(ch))) {
          SET_ERRNO(HPE_INVALID_VERSION);
          goto error;
        }

        parser.http_minor = ch - '0';
        UPDATE_STATE(s_req_http_end);
        break;

      case s_req_http_end:
      {
        if (ch == CR) {
          UPDATE_STATE(s_req_line_almost_done);
          break;
        }

        if (ch == LF) {
          UPDATE_STATE(s_header_field_start);
          break;
        }

        SET_ERRNO(HPE_INVALID_VERSION);
        goto error;
        break;
      }

      /* end of request line */
      case s_req_line_almost_done:
      {
        if ((ch != LF)) {
          SET_ERRNO(HPE_LF_EXPECTED);
          goto error;
        }

        UPDATE_STATE(s_header_field_start);
        break;
      }

      case s_header_field_start:
      {
        if (ch == CR) {
          UPDATE_STATE(s_headers_almost_done);
          break;
        }

        if (ch == LF) {
          /* they might be just sending \n instead of \r\n so this would be
           * the second \n to denote the end of headers*/
          UPDATE_STATE(s_headers_almost_done);
          REEXECUTE();
        }

        c = TOKEN(ch);

        if ((!c)) {
          SET_ERRNO(HPE_INVALID_HEADER_TOKEN);
          goto error;
        }

        MARK(header_field);

        parser.index = 0;
        UPDATE_STATE(s_header_field);

        switch (c) {
          case 'c':
            parser.header_state = h_C;
            break;

          case 'p':
            parser.header_state = h_matching_proxy_connection;
            break;

          case 't':
            parser.header_state = h_matching_transfer_encoding;
            break;

          case 'u':
            parser.header_state = h_matching_upgrade;
            break;

          default:
            parser.header_state = h_general;
            break;
        }
        break;
      }

      case s_header_field:
      {
        const char* start = p;
        for (; p != data + len; p++) {
          ch = *p;
          c = TOKEN(ch);

          if (!c)
            break;

          switch (parser.header_state) {
            case h_general:
              break;

            case h_C:
              parser.index++;
              parser.header_state = (c == 'o' ? h_CO : h_general);
              break;

            case h_CO:
              parser.index++;
              parser.header_state = (c == 'n' ? h_CON : h_general);
              break;

            case h_CON:
              parser.index++;
              switch (c) {
                case 'n':
                  parser.header_state = h_matching_connection;
                  break;
                case 't':
                  parser.header_state = h_matching_content_length;
                  break;
                default:
                  parser.header_state = h_general;
                  break;
              }
              break;

            /* connection */

            case h_matching_connection:
              parser.index++;
              if (parser.index > sizeof(CONNECTION)-1
                  || c != CONNECTION[parser.index]) {
                parser.header_state = h_general;
              } else if (parser.index == sizeof(CONNECTION)-2) {
                parser.header_state = h_connection;
              }
              break;

            /* proxy-connection */

            case h_matching_proxy_connection:
              parser.index++;
              if (parser.index > sizeof(PROXY_CONNECTION)-1
                  || c != PROXY_CONNECTION[parser.index]) {
                parser.header_state = h_general;
              } else if (parser.index == sizeof(PROXY_CONNECTION)-2) {
                parser.header_state = h_connection;
              }
              break;

            /* content-length */

            case h_matching_content_length:
              parser.index++;
              if (parser.index > sizeof(CONTENT_LENGTH)-1
                  || c != CONTENT_LENGTH[parser.index]) {
                parser.header_state = h_general;
              } else if (parser.index == sizeof(CONTENT_LENGTH)-2) {
                parser.header_state = h_content_length;
              }
              break;

            /* transfer-encoding */

            case h_matching_transfer_encoding:
              parser.index++;
              if (parser.index > sizeof(TRANSFER_ENCODING)-1
                  || c != TRANSFER_ENCODING[parser.index]) {
                parser.header_state = h_general;
              } else if (parser.index == sizeof(TRANSFER_ENCODING)-2) {
                parser.header_state = h_transfer_encoding;
              }
              break;

            /* upgrade */

            case h_matching_upgrade:
              parser.index++;
              if (parser.index > sizeof(UPGRADE)-1
                  || c != UPGRADE[parser.index]) {
                parser.header_state = h_general;
              } else if (parser.index == sizeof(UPGRADE)-2) {
                parser.header_state = h_upgrade;
              }
              break;

            case h_connection:
            case h_content_length:
            case h_transfer_encoding:
            case h_upgrade:
              if (ch != ' ') parser.header_state = h_general;
              break;

            default:
              assert(0 && "Unknown header_state");
              break;
          }
        }

        COUNT_HEADER_SIZE(p - start);

        if (p == data + len) {
          --p;
          break;
        }

        if (ch == ':') {
          UPDATE_STATE(s_header_value_discard_ws);
          CALLBACK_DATA(header_field);
          break;
        }

        SET_ERRNO(HPE_INVALID_HEADER_TOKEN);
        goto error;
      }

      case s_header_value_discard_ws:
        if (ch == ' ' || ch == '\t') break;

        if (ch == CR) {
          UPDATE_STATE(s_header_value_discard_ws_almost_done);
          break;
        }

        if (ch == LF) {
          UPDATE_STATE(s_header_value_discard_lws);
          break;
        }

        /* FALLTHROUGH */

      case s_header_value_start:
      {
        MARK(header_value);

        UPDATE_STATE(s_header_value);
        parser.index = 0;

        c = LOWER(ch);

        switch (parser.header_state) {
          case h_upgrade:
            parser.flags |= F_UPGRADE;
            parser.header_state = h_general;
            break;

          case h_transfer_encoding:
            /* looking for 'Transfer-Encoding: chunked' */
            if ('c' == c) {
              parser.header_state = h_matching_transfer_encoding_chunked;
            } else {
              parser.header_state = h_general;
            }
            break;

          case h_content_length:
            if ((!IS_NUM(ch))) {
              SET_ERRNO(HPE_INVALID_CONTENT_LENGTH);
              goto error;
            }

            if (parser.flags & F_CONTENTLENGTH) {
              SET_ERRNO(HPE_UNEXPECTED_CONTENT_LENGTH);
              goto error;
            }

            parser.flags |= F_CONTENTLENGTH;
            parser.content_length = ch - '0';
            parser.header_state = h_content_length_num;
            break;

          case h_connection:
            /* looking for 'Connection: keep-alive' */
            if (c == 'k') {
              parser.header_state = h_matching_connection_keep_alive;
            /* looking for 'Connection: close' */
            } else if (c == 'c') {
              parser.header_state = h_matching_connection_close;
            } else if (c == 'u') {
              parser.header_state = h_matching_connection_upgrade;
            } else {
              parser.header_state = h_matching_connection_token;
            }
            break;

          /* Multi-value `Connection` header */
          case h_matching_connection_token_start:
            break;

          default:
            parser.header_state = h_general;
            break;
        }
        break;
      }

      case s_header_value:
      {
        const char* start = p;
        header_states h_state = cast(header_states) parser.header_state;
        for (; p != data + len; p++) {
          ch = *p;
          if (ch == CR) {
            UPDATE_STATE(s_header_almost_done);
            parser.header_state = h_state;
            CALLBACK_DATA(header_value);
            break;
          }

          if (ch == LF) {
            UPDATE_STATE(s_header_almost_done);
            COUNT_HEADER_SIZE(p - start);
            parser.header_state = h_state;
            CALLBACK_DATA_NOADVANCE(header_value);
            REEXECUTE();
          }

          if (!lenient && !IS_HEADER_CHAR(ch)) {
            SET_ERRNO(HPE_INVALID_HEADER_TOKEN);
            goto error;
          }

          c = LOWER(ch);

          switch (h_state) {
            case h_general:
            {
              const char* p_cr;
              const char* p_lf;
              size_t limit = data + len - p;

              limit = MIN(limit, HTTP_MAX_HEADER_SIZE);

              p_cr = cast(const char*) memchr(p, CR, limit);
              p_lf = cast(const char*) memchr(p, LF, limit);
              if (p_cr != NULL) {
                if (p_lf != NULL && p_cr >= p_lf)
                  p = p_lf;
                else
                  p = p_cr;
              } else if ((p_lf != NULL)) {
                p = p_lf;
              } else {
                p = data + len;
              }
              --p;

              break;
            }

            case h_connection:
            case h_transfer_encoding:
              assert(0 && "Shouldn't get here.");
              break;

            case h_content_length:
              if (ch == ' ') break;
              h_state = h_content_length_num;
              /* FALLTHROUGH */

            case h_content_length_num:
            {
              uint64_t t;

              if (ch == ' ') {
                h_state = h_content_length_ws;
                break;
              }

              if ((!IS_NUM(ch))) {
                SET_ERRNO(HPE_INVALID_CONTENT_LENGTH);
                parser.header_state = h_state;
                goto error;
              }

              t = parser.content_length;
              t *= 10;
              t += ch - '0';

              /* Overflow? Test against a conservative limit for simplicity. */
              if (((ULLONG_MAX - 10) / 10 < parser.content_length)) {
                SET_ERRNO(HPE_INVALID_CONTENT_LENGTH);
                parser.header_state = h_state;
                goto error;
              }

              parser.content_length = t;
              break;
            }

            case h_content_length_ws:
              if (ch == ' ') break;
              SET_ERRNO(HPE_INVALID_CONTENT_LENGTH);
              parser.header_state = h_state;
              goto error;

            /* Transfer-Encoding: chunked */
            case h_matching_transfer_encoding_chunked:
              parser.index++;
              if (parser.index > sizeof(CHUNKED)-1
                  || c != CHUNKED[parser.index]) {
                h_state = h_general;
              } else if (parser.index == sizeof(CHUNKED)-2) {
                h_state = h_transfer_encoding_chunked;
              }
              break;

            case h_matching_connection_token_start:
              /* looking for 'Connection: keep-alive' */
              if (c == 'k') {
                h_state = h_matching_connection_keep_alive;
              /* looking for 'Connection: close' */
              } else if (c == 'c') {
                h_state = h_matching_connection_close;
              } else if (c == 'u') {
                h_state = h_matching_connection_upgrade;
              } else if (STRICT_TOKEN(c)) {
                h_state = h_matching_connection_token;
              } else if (c == ' ' || c == '\t') {
                /* Skip lws */
              } else {
                h_state = h_general;
              }
              break;

            /* looking for 'Connection: keep-alive' */
            case h_matching_connection_keep_alive:
              parser.index++;
              if (parser.index > sizeof(KEEP_ALIVE)-1
                  || c != KEEP_ALIVE[parser.index]) {
                h_state = h_matching_connection_token;
              } else if (parser.index == sizeof(KEEP_ALIVE)-2) {
                h_state = h_connection_keep_alive;
              }
              break;

            /* looking for 'Connection: close' */
            case h_matching_connection_close:
              parser.index++;
              if (parser.index > sizeof(CLOSE)-1 || c != CLOSE[parser.index]) {
                h_state = h_matching_connection_token;
              } else if (parser.index == sizeof(CLOSE)-2) {
                h_state = h_connection_close;
              }
              break;

            /* looking for 'Connection: upgrade' */
            case h_matching_connection_upgrade:
              parser.index++;
              if (parser.index > sizeof(UPGRADE) - 1 ||
                  c != UPGRADE[parser.index]) {
                h_state = h_matching_connection_token;
              } else if (parser.index == sizeof(UPGRADE)-2) {
                h_state = h_connection_upgrade;
              }
              break;

            case h_matching_connection_token:
              if (ch == ',') {
                h_state = h_matching_connection_token_start;
                parser.index = 0;
              }
              break;

            case h_transfer_encoding_chunked:
              if (ch != ' ') h_state = h_general;
              break;

            case h_connection_keep_alive:
            case h_connection_close:
            case h_connection_upgrade:
              if (ch == ',') {
                if (h_state == h_connection_keep_alive) {
                  parser.flags |= F_CONNECTION_KEEP_ALIVE;
                } else if (h_state == h_connection_close) {
                  parser.flags |= F_CONNECTION_CLOSE;
                } else if (h_state == h_connection_upgrade) {
                  parser.flags |= F_CONNECTION_UPGRADE;
                }
                h_state = h_matching_connection_token_start;
                parser.index = 0;
              } else if (ch != ' ') {
                h_state = h_matching_connection_token;
              }
              break;

            default:
              UPDATE_STATE(s_header_value);
              h_state = h_general;
              break;
          }
        }
        parser.header_state = h_state;

        COUNT_HEADER_SIZE(p - start);

        if (p == data + len)
          --p;
        break;
      }

      case s_header_almost_done:
      {
        if ((ch != LF)) {
          SET_ERRNO(HPE_LF_EXPECTED);
          goto error;
        }

        UPDATE_STATE(s_header_value_lws);
        break;
      }

      case s_header_value_lws:
      {
        if (ch == ' ' || ch == '\t') {
          UPDATE_STATE(s_header_value_start);
          REEXECUTE();
        }

        /* finished the header */
        switch (parser.header_state) {
          case h_connection_keep_alive:
            parser.flags |= F_CONNECTION_KEEP_ALIVE;
            break;
          case h_connection_close:
            parser.flags |= F_CONNECTION_CLOSE;
            break;
          case h_transfer_encoding_chunked:
            parser.flags |= F_CHUNKED;
            break;
          case h_connection_upgrade:
            parser.flags |= F_CONNECTION_UPGRADE;
            break;
          default:
            break;
        }

        UPDATE_STATE(s_header_field_start);
        REEXECUTE();
      }

      case s_header_value_discard_ws_almost_done:
      {
        STRICT_CHECK(ch != LF);
        UPDATE_STATE(s_header_value_discard_lws);
        break;
      }

      case s_header_value_discard_lws:
      {
        if (ch == ' ' || ch == '\t') {
          UPDATE_STATE(s_header_value_discard_ws);
          break;
        } else {
          switch (parser.header_state) {
            case h_connection_keep_alive:
              parser.flags |= F_CONNECTION_KEEP_ALIVE;
              break;
            case h_connection_close:
              parser.flags |= F_CONNECTION_CLOSE;
              break;
            case h_connection_upgrade:
              parser.flags |= F_CONNECTION_UPGRADE;
              break;
            case h_transfer_encoding_chunked:
              parser.flags |= F_CHUNKED;
              break;
            default:
              break;
          }

          /* header value was empty */
          MARK(header_value);
          UPDATE_STATE(s_header_field_start);
          CALLBACK_DATA_NOADVANCE(header_value);
          REEXECUTE();
        }
      }

      case s_headers_almost_done:
      {
        STRICT_CHECK(ch != LF);

        if (parser.flags & F_TRAILING) {
          /* End of a chunked request */
          UPDATE_STATE(s_message_done);
          CALLBACK_NOTIFY_NOADVANCE(chunk_complete);
          REEXECUTE();
        }

        /* Cannot use chunked encoding and a content-length header together
           per the HTTP specification. */
        if ((parser.flags & F_CHUNKED) &&
            (parser.flags & F_CONTENTLENGTH)) {
          SET_ERRNO(HPE_UNEXPECTED_CONTENT_LENGTH);
          goto error;
        }

        UPDATE_STATE(s_headers_done);

        /* Set this here so that on_headers_complete() callbacks can see it */
        if ((parser.flags & F_UPGRADE) &&
            (parser.flags & F_CONNECTION_UPGRADE)) {
          /* For responses, "Upgrade: foo" and "Connection: upgrade" are
           * mandatory only when it is a 101 Switching Protocols response,
           * otherwise it is purely informational, to announce support.
           */
          parser.upgrade =
              (parser.type == HTTP_REQUEST || parser.status_code == 101);
        } else {
          parser.upgrade = (parser.method == HTTP_CONNECT);
        }

        /* Here we call the headers_complete callback. This is somewhat
         * different than other callbacks because if the user returns 1, we
         * will interpret that as saying that this message has no body. This
         * is needed for the annoying case of recieving a response to a HEAD
         * request.
         *
         * We'd like to use CALLBACK_NOTIFY_NOADVANCE() here but we cannot, so
         * we have to simulate it by handling a change in errno below.
         */
        if (settings.on_headers_complete) {
          switch (settings.on_headers_complete(parser)) {
            case 0:
              break;

            case 2:
              parser.upgrade = 1;

            /* FALLTHROUGH */
            case 1:
              parser.flags |= F_SKIPBODY;
              break;

            default:
              SET_ERRNO(HPE_CB_headers_complete);
              RETURN(p - data); /* Error */
          }
        }

        if (HTTP_PARSER_ERRNO(parser) != HPE_OK) {
          RETURN(p - data);
        }

        REEXECUTE();
      }

      case s_headers_done:
      {
        int hasBody;
        STRICT_CHECK(ch != LF);

        parser.nread = 0;

        hasBody = parser.flags & F_CHUNKED ||
          (parser.content_length > 0 && parser.content_length != ULLONG_MAX);
        if (parser.upgrade && (parser.method == HTTP_CONNECT ||
                                (parser.flags & F_SKIPBODY) || !hasBody)) {
          /* Exit, the rest of the message is in a different protocol. */
          UPDATE_STATE(NEW_MESSAGE());
          CALLBACK_NOTIFY(message_complete);
          RETURN((p - data) + 1);
        }

        if (parser.flags & F_SKIPBODY) {
          UPDATE_STATE(NEW_MESSAGE());
          CALLBACK_NOTIFY(message_complete);
        } else if (parser.flags & F_CHUNKED) {
          /* chunked encoding - ignore Content-Length header */
          UPDATE_STATE(s_chunk_size_start);
        } else {
          if (parser.content_length == 0) {
            /* Content-Length header given but zero: Content-Length: 0\r\n */
            UPDATE_STATE(NEW_MESSAGE());
            CALLBACK_NOTIFY(message_complete);
          } else if (parser.content_length != ULLONG_MAX) {
            /* Content-Length header given and non-zero */
            UPDATE_STATE(s_body_identity);
          } else {
            if (!http_message_needs_eof(parser)) {
              /* Assume content-length 0 - read the next */
              UPDATE_STATE(NEW_MESSAGE());
              CALLBACK_NOTIFY(message_complete);
            } else {
              /* Read body until EOF */
              UPDATE_STATE(s_body_identity_eof);
            }
          }
        }

        break;
      }

      case s_body_identity:
      {
        uint64_t to_read = MIN(parser.content_length,
                               cast(uint64_t) ((data + len) - p));

        assert(parser.content_length != 0
            && parser.content_length != ULLONG_MAX);

        /* The difference between advancing content_length and p is because
         * the latter will automaticaly advance on the next loop iteration.
         * Further, if content_length ends up at 0, we want to see the last
         * byte again for our message complete callback.
         */
        MARK(body);
        parser.content_length -= to_read;
        p += to_read - 1;

        if (parser.content_length == 0) {
          UPDATE_STATE(s_message_done);

          /* Mimic CALLBACK_DATA_NOADVANCE() but with one extra byte.
           *
           * The alternative to doing this is to wait for the next byte to
           * trigger the data callback, just as in every other case. The
           * problem with this is that this makes it difficult for the test
           * harness to distinguish between complete-on-EOF and
           * complete-on-length. It's not clear that this distinction is
           * important for applications, but let's keep it for now.
           */
          CALLBACK_DATA_(body, p - body_mark + 1, p - data);
          REEXECUTE();
        }

        break;
      }

      /* read until EOF */
      case s_body_identity_eof:
        MARK(body);
        p = data + len - 1;

        break;

      case s_message_done:
        UPDATE_STATE(NEW_MESSAGE());
        CALLBACK_NOTIFY(message_complete);
        if (parser.upgrade) {
          /* Exit, the rest of the message is in a different protocol. */
          RETURN((p - data) + 1);
        }
        break;

      case s_chunk_size_start:
      {
        assert(parser.nread == 1);
        assert(parser.flags & F_CHUNKED);

        unhex_val = unhex[ch];
        if ((unhex_val == -1)) {
          SET_ERRNO(HPE_INVALID_CHUNK_SIZE);
          goto error;
        }

        parser.content_length = unhex_val;
        UPDATE_STATE(s_chunk_size);
        break;
      }

      case s_chunk_size:
      {
        uint64_t t;

        assert(parser.flags & F_CHUNKED);

        if (ch == CR) {
          UPDATE_STATE(s_chunk_size_almost_done);
          break;
        }

        unhex_val = unhex[ch];

        if (unhex_val == -1) {
          if (ch == ';' || ch == ' ') {
            UPDATE_STATE(s_chunk_parameters);
            break;
          }

          SET_ERRNO(HPE_INVALID_CHUNK_SIZE);
          goto error;
        }

        t = parser.content_length;
        t *= 16;
        t += unhex_val;

        /* Overflow? Test against a conservative limit for simplicity. */
        if (((ULLONG_MAX - 16) / 16 < parser.content_length)) {
          SET_ERRNO(HPE_INVALID_CONTENT_LENGTH);
          goto error;
        }

        parser.content_length = t;
        break;
      }

      case s_chunk_parameters:
      {
        assert(parser.flags & F_CHUNKED);
        /* just ignore this shit. TODO check for overflow */
        if (ch == CR) {
          UPDATE_STATE(s_chunk_size_almost_done);
          break;
        }
        break;
      }

      case s_chunk_size_almost_done:
      {
        assert(parser.flags & F_CHUNKED);
        STRICT_CHECK(ch != LF);

        parser.nread = 0;

        if (parser.content_length == 0) {
          parser.flags |= F_TRAILING;
          UPDATE_STATE(s_header_field_start);
        } else {
          UPDATE_STATE(s_chunk_data);
        }
        CALLBACK_NOTIFY(chunk_header);
        break;
      }

      case s_chunk_data:
      {
        ulong to_read = MIN(parser.content_length,
                               ((data + len) - p));

        assert(parser.flags & F_CHUNKED);
        assert(parser.content_length != 0
            && parser.content_length != ULLONG_MAX);

        /* See the explanation in s_body_identity for why the content
         * length and data pointers are managed this way.
         */
        MARK(body);
        parser.content_length -= to_read;
        p += to_read - 1;

        if (parser.content_length == 0) {
          UPDATE_STATE(s_chunk_data_almost_done);
        }

        break;
      }

      case s_chunk_data_almost_done:
        assert(parser.flags & F_CHUNKED);
        assert(parser.content_length == 0);
        STRICT_CHECK(ch != CR);
        UPDATE_STATE(s_chunk_data_done);
        CALLBACK_DATA(body);
        break;

      case s_chunk_data_done:
        assert(parser.flags & F_CHUNKED);
        STRICT_CHECK(ch != LF);
        parser.nread = 0;
        UPDATE_STATE(s_chunk_size_start);
        CALLBACK_NOTIFY(chunk_complete);
        break;

      default:
        assert(0 && "unhandled state");
        SET_ERRNO(HPE_INVALID_INTERNAL_STATE);
        goto error;
    }
  }

  /* Run callbacks for any marks that we have leftover after we ran our of
   * bytes. There should be at most one of these set, so it's OK to invoke
   * them in series (unset marks will not result in callbacks).
   *
   * We use the NOADVANCE() variety of callbacks here because 'p' has already
   * overflowed 'data' and this allows us to correct for the off-by-one that
   * we'd otherwise have (since CALLBACK_DATA() is meant to be run with a 'p'
   * value that's in-bounds).
   */

  assert(((header_field_mark ? 1 : 0) +
          (header_value_mark ? 1 : 0) +
          (url_mark ? 1 : 0)  +
          (body_mark ? 1 : 0) +
          (status_mark ? 1 : 0)) <= 1);

  CALLBACK_DATA_NOADVANCE(header_field);
  CALLBACK_DATA_NOADVANCE(header_value);
  CALLBACK_DATA_NOADVANCE(url);
  CALLBACK_DATA_NOADVANCE(body);
  CALLBACK_DATA_NOADVANCE(status);

  RETURN(len);

error:
  if (HTTP_PARSER_ERRNO(parser) == HPE_OK) {
    SET_ERRNO(HPE_UNKNOWN);
  }

  RETURN(p - data);
}


/* Does the parser need to see an EOF to find the end of the message? */
int
http_message_needs_eof (const http_parser *parser)
{
  if (parser.type == HTTP_REQUEST) {
    return 0;
  }

  /* See RFC 2616 section 4.4 */
  if (parser.status_code / 100 == 1 || /* 1xx e.g. Continue */
      parser.status_code == 204 ||     /* No Content */
      parser.status_code == 304 ||     /* Not Modified */
      parser.flags & F_SKIPBODY) {     /* response to a HEAD request */
    return 0;
  }

  if ((parser.flags & F_CHUNKED) || parser.content_length != ULLONG_MAX) {
    return 0;
  }

  return 1;
}


int
http_should_keep_alive (const http_parser *parser)
{
  if (parser.http_major > 0 && parser.http_minor > 0) {
    /* HTTP/1.1 */
    if (parser.flags & F_CONNECTION_CLOSE) {
      return 0;
    }
  } else {
    /* HTTP/1.0 or earlier */
    if (!(parser.flags & F_CONNECTION_KEEP_ALIVE)) {
      return 0;
    }
  }

  return !http_message_needs_eof(parser);
}


char * HttpMethod_str (HttpMethod m)
{
  return ELEM_AT(method_strings, m, "<unknown>");
}


void http_parser_init (http_parser *parser, HttpParserType t)
{
  void *data = parser.data; /* preserve application data */
  memset(parser, 0, sizeof(*parser));
  parser.data = data;
  parser.type = t;
  parser.state = (t == HTTP_REQUEST ? s_start_req : (t == HTTP_RESPONSE ? s_start_res : s_start_req_or_res));
  parser.http_errno = HPE_OK;
}

void http_parser_settings_init(http_parser_settings *settings)
{
  memset(settings, 0, sizeof(*settings));
}

char * http_errno_name(http_errno err) {
  assert((cast(size_t) err) < ARRAY_SIZE(http_strerror_tab));
  return http_strerror_tab[err].name;
}

char * http_errno_description(http_errno err) {
  assert((cast(size_t) err) < ARRAY_SIZE(http_strerror_tab));
  return http_strerror_tab[err].description;
}

static http_host_state http_parse_host_char(http_host_state s, const char ch) {
  switch(s) {
    case s_http_userinfo:
    case s_http_userinfo_start:
      if (ch == '@') {
        return s_http_host_start;
      }

      if (IS_USERINFO_CHAR(ch)) {
        return s_http_userinfo;
      }
      break;

    case s_http_host_start:
      if (ch == '[') {
        return s_http_host_v6_start;
      }

      if (IS_HOST_CHAR(ch)) {
        return s_http_host;
      }

      break;

    case s_http_host:
      if (IS_HOST_CHAR(ch)) {
        return s_http_host;
      }

    /* FALLTHROUGH */
    case s_http_host_v6_end:
      if (ch == ':') {
        return s_http_host_port_start;
      }

      break;

    case s_http_host_v6:
      if (ch == ']') {
        return s_http_host_v6_end;
      }

    /* FALLTHROUGH */
    case s_http_host_v6_start:
      if (IS_HEX(ch) || ch == ':' || ch == '.') {
        return s_http_host_v6;
      }

      if (s == s_http_host_v6 && ch == '%') {
        return s_http_host_v6_zone_start;
      }
      break;

    case s_http_host_v6_zone:
      if (ch == ']') {
        return s_http_host_v6_end;
      }

    /* FALLTHROUGH */
    case s_http_host_v6_zone_start:
      /* RFC 6874 Zone ID consists of 1*( unreserved / pct-encoded) */
      if (IS_ALPHANUM(ch) || ch == '%' || ch == '.' || ch == '-' || ch == '_' ||
          ch == '~') {
        return s_http_host_v6_zone;
      }
      break;

    case s_http_host_port:
    case s_http_host_port_start:
      if (IS_NUM(ch)) {
        return s_http_host_port;
      }

      break;

    default:
      break;
  }
  return s_http_host_dead;
}

static int
http_parse_host(const char * buf, http_parser_url *u, int found_at) {
  enum http_host_state s;

  const char *p;
  size_t buflen = u.field_data[UF_HOST].off + u.field_data[UF_HOST].len;

  assert(u.field_set & (1 << UF_HOST));

  u.field_data[UF_HOST].len = 0;

  s = found_at ? s_http_userinfo_start : s_http_host_start;

  for (p = buf + u.field_data[UF_HOST].off; p < buf + buflen; p++) {
    enum http_host_state new_s = http_parse_host_char(s, *p);

    if (new_s == s_http_host_dead) {
      return 1;
    }

    switch(new_s) {
      case s_http_host:
        if (s != s_http_host) {
          u.field_data[UF_HOST].off = p - buf;
        }
        u.field_data[UF_HOST].len++;
        break;

      case s_http_host_v6:
        if (s != s_http_host_v6) {
          u.field_data[UF_HOST].off = p - buf;
        }
        u.field_data[UF_HOST].len++;
        break;

      case s_http_host_v6_zone_start:
      case s_http_host_v6_zone:
        u.field_data[UF_HOST].len++;
        break;

      case s_http_host_port:
        if (s != s_http_host_port) {
          u.field_data[UF_PORT].off = p - buf;
          u.field_data[UF_PORT].len = 0;
          u.field_set |= (1 << UF_PORT);
        }
        u.field_data[UF_PORT].len++;
        break;

      case s_http_userinfo:
        if (s != s_http_userinfo) {
          u.field_data[UF_USERINFO].off = p - buf ;
          u.field_data[UF_USERINFO].len = 0;
          u.field_set |= (1 << UF_USERINFO);
        }
        u.field_data[UF_USERINFO].len++;
        break;

      default:
        break;
    }
    s = new_s;
  }

  /* Make sure we don't end somewhere unexpected */
  switch (s) {
    case s_http_host_start:
    case s_http_host_v6_start:
    case s_http_host_v6:
    case s_http_host_v6_zone_start:
    case s_http_host_v6_zone:
    case s_http_host_port_start:
    case s_http_userinfo:
    case s_http_userinfo_start:
      return 1;
    default:
      break;
  }

  return 0;
}

void http_parser_url_init(http_parser_url *u) {
  memset(u, 0, sizeof(*u));
}

int http_parser_parse_url(const char *buf, size_t buflen, int is_connect, http_parser_url *u)
{
  enum state s;
  const char *p;
  enum http_parser_url_fields uf, old_uf;
  int found_at = 0;

  u.port = u.field_set = 0;
  s = is_connect ? s_req_server_start : s_req_spaces_before_url;
  old_uf = UF_MAX;

  for (p = buf; p < buf + buflen; p++) {
    s = parse_url_char(s, *p);

    /* Figure out the next field that we're operating on */
    switch (s) {
      case s_dead:
        return 1;

      /* Skip delimeters */
      case s_req_schema_slash:
      case s_req_schema_slash_slash:
      case s_req_server_start:
      case s_req_query_string_start:
      case s_req_fragment_start:
        continue;

      case s_req_schema:
        uf = UF_SCHEMA;
        break;

      case s_req_server_with_at:
        found_at = 1;

      /* FALLTHROUGH */
      case s_req_server:
        uf = UF_HOST;
        break;

      case s_req_path:
        uf = UF_PATH;
        break;

      case s_req_query_string:
        uf = UF_QUERY;
        break;

      case s_req_fragment:
        uf = UF_FRAGMENT;
        break;

      default:
        assert(!"Unexpected state");
        return 1;
    }

    /* Nothing's changed; soldier on */
    if (uf == old_uf) {
      u.field_data[uf].len++;
      continue;
    }

    u.field_data[uf].off = p - buf;
    u.field_data[uf].len = 1;

    u.field_set |= (1 << uf);
    old_uf = uf;
  }

  /* host must be present if there is a schema */
  /* parsing http:///toto will fail */
  if ((u.field_set & (1 << UF_SCHEMA)) &&
      (u.field_set & (1 << UF_HOST)) == 0) {
    return 1;
  }

  if (u.field_set & (1 << UF_HOST)) {
    if (http_parse_host(buf, u, found_at) != 0) {
      return 1;
    }
  }

  /* CONNECT requests can only contain "hostname:port" */
  if (is_connect && u.field_set != ((1 << UF_HOST)|(1 << UF_PORT))) {
    return 1;
  }

  if (u.field_set & (1 << UF_PORT)) {
    uint16_t off;
    uint16_t len;
    const char* p;
    const char* end;
    ulong v;

    off = u.field_data[UF_PORT].off;
    len = u.field_data[UF_PORT].len;
    end = buf + off + len;

    /* NOTE: The characters are already validated and are in the [0-9] range */
    assert(off + len <= buflen && "Port number overflow");
    v = 0;
    for (p = buf + off; p < end; p++) {
      v *= 10;
      v += *p - '0';

      /* Ports have a max value of 2^16 */
      if (v > 0xffff) {
        return 1;
      }
    }

    u.port = cast(ushort) v;
  }

  return 0;
}

void http_parser_pause(http_parser *parser, int paused) {
  /* Users should only be pausing/unpausing a parser that is not in an error
   * state. In non-debug builds, there's not much that we can do about this
   * other than ignore it.
   */
  if (HTTP_PARSER_ERRNO(parser) == HPE_OK ||
      HTTP_PARSER_ERRNO(parser) == HPE_PAUSED) {
    SET_ERRNO((paused) ? HPE_PAUSED : HPE_OK);
  } else {
    assert(0 && "Attempting to pause parser in error state");
  }
}

int http_body_is_final(const http_parser *parser) {
    return parser.state == s_message_done;
}

ulong http_parser_version() {
  return HTTP_PARSER_VERSION_MAJOR * 0x10000 |
         HTTP_PARSER_VERSION_MINOR * 0x00100 |
         HTTP_PARSER_VERSION_PATCH * 0x00001;
}


// =========== Public interface starts here =============

public:

class HttpException : Exception {
	HttpError error;

	pure @nogc nothrow this(HttpError error, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
    	this.error = error;
    	immutable char* str = http_errno_description(error);
        super(str[0..strlen(str)], file, line, nextInChain);
    }
}

struct HttpParser(Interceptor)
{
	http_parser parser;
	http_parser_settings settings;
	Interceptor interceptor;
	Throwable failure;
	uint flags;

	static generateCallback(string cName, string dName)
	{
		import std.format;
		return format(`
			static if(__traits(hasMember, interceptor, "%2$s"))
			{
				extern(C) static int %1$s(http_parser* p) {
					auto parser = cast(HttpParser*)p;
					try {
						parser.flags = http_parser_flags(p);
						return parser.interceptor.%2$s(parser);
					}
					catch (Throwable t) {
						parser.failure = t;
						return 1;
					}
				}
				settings.%1$s = &%1$s;
			}
		`, cName, dName);
	}

	static generateCallbackWithData(string cName, string dName)
	{
		import std.format;
		return format(`
			static if(__traits(hasMember, interceptor, "%2$s"))
			{
				extern(C) static int %1$s(http_parser* p, const ubyte* at, size_t size) {
					auto parser = cast(HttpParser*)p;
					try {
						parser.flags = http_parser_flags(p);
						return parser.interceptor.%2$s(parser, at[0..size]);
					}
					catch (Throwable t) {
						parser.failure = t;
						return 1;
					}
				}
				settings.%1$s = &%1$s;
			}
		`, cName, dName);
	}

	@property HttpError errorCode() pure @safe nothrow  { return cast(HttpError)((flags >> 24) & 0x7f); }

public:
	alias interceptor this;

	@property uint status() pure @safe nothrow  { return flags & 0xffff; }

	@property HttpMethod method() pure @safe nothrow  { return cast(HttpMethod)((flags >> 16) & 0xFF); }

	this(Interceptor interceptor, HttpParserType type)
	{
		this.interceptor = interceptor;
		http_parser_init(&parser, type);
		mixin(generateCallback("on_message_begin", "onMessageBegin"));
		mixin(generateCallbackWithData("on_url", "onUrl"));
		mixin(generateCallbackWithData("on_status", "onStatus"));
		mixin(generateCallbackWithData("on_body", "onBody"));
		mixin(generateCallbackWithData("on_header_field", "onHeaderField"));
		mixin(generateCallbackWithData("on_header_value", "onHeaderValue"));
		mixin(generateCallback("on_headers_complete", "onHeadersComplete"));
		mixin(generateCallback("on_message_complete", "onMessageComplete"));
	}

	@property bool shouldKeepAlive() pure nothrow { return http_should_keep_alive(&parser) == 1; }

	@property ushort httpMajor() @safe pure nothrow { return parser.http_major; }

	@property ushort httpMinor() @safe pure nothrow { return parser.http_minor; }

	size_t execute(const(ubyte)[] chunk)
	{
		size_t size = http_parser_execute(&parser, &settings, chunk.ptr, chunk.length);
		flags = http_parser_flags(&parser);
		if (errorCode) {
			auto f = failure;
			failure = null;
			if (f is null) f = new HttpException(errorCode);
			throw f;
		}
		return size;
	}

	size_t execute(const(char)[] str)
	{
		return execute(cast(const(ubyte)[])str);
	}
}

auto httpParser(Interceptor)(Interceptor interceptor, HttpParserType type)
{
	return HttpParser!Interceptor(interceptor, type);
}

unittest
{
	import std.conv : to, text;

	struct TestCase {
		HttpParserType type;
		string raw;
		string url;
		string _body;
		bool shouldKeepAlive;
		ushort major;
		ushort minor;
		string[2][] headers;
	}

	auto tests = [
		TestCase(
			HttpParserType.request,
			 "GET /test HTTP/1.1\r\n" ~
	         "User-Agent: curl/7.18.0 (i486-pc-linux-gnu) libcurl/7.18.0 OpenSSL/0.9.8g zlib/1.2.3.3 libidn/1.1\r\n" ~
	         "Host: 0.0.0.0=5000\r\n" ~
	         "Accept: */*\r\n" ~
	         "Content-Length: 2\r\n" ~
	         "\r\n42",
	         "/test",
	         "42",
	         true, 1, 1,
			 [
			 	[ "User-Agent", "curl/7.18.0 (i486-pc-linux-gnu) libcurl/7.18.0 OpenSSL/0.9.8g zlib/1.2.3.3 libidn/1.1" ],
			 	[ "Host", "0.0.0.0=5000" ],
			 	[ "Accept", "*/*" ],
			 	[ "Content-Length", "2"]
		     ]
         )
	];

	// Tests consume inout in one go, we just test that proper callbacks get called

	struct Callbacks {
		int testCase;
		string url;
		string[] headerFields;
		string[] headerValues;
		string _body;
		bool headersCompleted = false;

		int onMessageBegin(HttpParser!Callbacks* parser) {
			headerValues = [];
			headerFields = [];
			headersCompleted = false;
			url = "";
			return 0;
		}

		int onUrl(HttpParser!Callbacks* parser, const(ubyte)[] chunk){
			url = cast(string)chunk.idup;
			return 0;
		}

		int onHeaderField(HttpParser!Callbacks* parser, const(ubyte)[] chunk) {
			headerFields ~= cast(string)chunk;
			return 0;
		}

		int onHeaderValue(HttpParser!Callbacks* parser, const(ubyte)[] chunk) {
			headerValues ~= cast(string)chunk;
			return 0;
		}

		int onBody(HttpParser!Callbacks* parser, const(ubyte)[] chunk) {
			_body = cast(string)chunk;
			return 0;
		}

		int onStatus(HttpParser!Callbacks* parser, const(ubyte)[] chunk) { return 0; }

		int onHeadersComplete(HttpParser!Callbacks* parser) {
			auto test = tests[testCase];
			assert(test.url == url);
			assert(test.major == parser.httpMajor);
			assert(test.minor == parser.httpMinor);
			foreach(i, header; test.headers) {
				assert(headerFields[i] == header[0],
					text("header field mismatch got `", headerFields[i], "` expected `", header[0], "`"));
				assert(headerValues[i] == header[1],
					text("header value mismatch got `", headerValues[i], "` expected `", header[1], "`"));
			}
			headersCompleted = true;
			return 0;
		}

		int onMessageComplete(HttpParser!Callbacks* parser) {
			auto test = tests[testCase++];
			assert(headersCompleted);
			assert(test.url == url);
			assert(test.major == parser.httpMajor);
			assert(test.minor == parser.httpMinor);
			assert(test._body == _body);
			foreach(i, header; test.headers) {
				assert(headerFields[i] == header[0],
					text("header field mismatch got `", headerFields[i], "` expected `", header[0], "`"));
				assert(headerValues[i] == header[1],
					text("header value mismatch got `", headerValues[i], "` expected `", header[1], "`"));
			}
			return 0;
		}
	}

	auto parser = httpParser(Callbacks(), HttpParserType.both);
	foreach(t; tests) {
		parser.execute(t.raw);
	}
	assert(parser.testCase == tests.length);
}

