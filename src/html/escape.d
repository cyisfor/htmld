module html.escape;
  import std.stdio;
  import std.traits: EnumMembers;
  import std.conv: to;

import html: HTMLString;

enum HTMLEscapes {
  lt = '<',
  gt = '>',
};

enum AttributeEscapes {
  quot = '"',
  apos = '\'',
}

enum NamedEscapes {
  nbsp = ' ',
  amp = '&'
}

import std.array: Appender;

bool unescapeEnum(alias Escapes)
  (ref HTMLString chunk,
   ref Appender!HTMLString app) {
  import std.string: startsWith;
  foreach(e;EnumMembers!Escapes) {
	auto repr = e.to!dchar.to!string;
	auto name = e.to!string;
	if(repr == "\"")
	  repr = "\\\"";
	if(chunk.startsWith(name ~ ";")) {
	  app.put(repr);
	  app.put(chunk[name.length+1..$]);
	  return true;
	}
  }
  return false;
}

bool escapeEnum(alias Escapes)
  (const(char) c,
   ref HTMLString dest) {
  foreach(e;EnumMembers!Escapes) {
	if(c == e) {
	  auto name = e.to!string;
	  // mehh
	  dest = "&" ~ name ~ ";";
	  return true;
	}
  }
  return false;
}

auto unescape(bool unicode = true,
			  bool html = false,
			  bool attribute = false)
  (HTMLString s) {
  import std.array: appender;
  import std.algorithm.iteration: splitter;
  import std.conv: to;
  import std.string: isNumeric;
  import std.algorithm.searching: countUntil, count,startsWith;
  auto app = appender!HTMLString;
  auto chunks = s.splitter("&");
  if(chunks.empty) return s;
  chunks.popFront();
  if(chunks.empty) return s;

  foreach(chunk; chunks) {
	bool handle() {
	  if(chunk.length == 0) return false;
	  static if(html) {
		if(unescapeEnum!HTMLEscapes(chunk,app)) return true;
	  }
	  static if(attribute) {
		if(unescapeEnum!AttributeEscapes(chunk,app)) return true;
	  }
	  static if(unicode) {
		switch(chunk[0]) {
		case '#':
		  auto pos = chunk[1..$].countUntil(';');
		  if(pos < 0) return false;
		  auto num = chunk[1..pos+1];
		  if(!isNumeric(num)) return false;
		  app.put(num.to!int.to!dchar.to!string);
		  app.put(chunk[pos+2..$]);
		  return true;
		case 'x':
		  auto pos = chunk[1..$].countUntil(';');
		  if(pos < 0) return false;
		  auto num = chunk[1..pos+1];
		  if(num.count!((c) => 0 == "abcdefABCDEF0123456789".count(c)) > 0)
			return false;

		  app.put(to!int(num,0x10).to!dchar.to!string);
		  app.put(chunk[pos+2..$]);
		  return true;
		default:
		  if(unescapeEnum!NamedEscapes(chunk,app)) return true;
		}
	  }
	  return false;
	}
	if(!handle()) {
	  app.put('&');
	  app.put(chunk);
	}
  }
  return app.data;
}

unittest {
  import std.stdio;
  import std.algorithm.comparison: equal;
  void assert_equal(HTMLString a, HTMLString b) {
	if(a != b) {
	  writeln("fail");
	  writeln(a);
	  writeln(b);
	  assert(false);
	}
  }
  assert_equal
	(unescape!(true,true,true)("&lt;html&gt;&amp;amp; &#42; &x42;"),
	 "<html>&amp; * B");
}

auto escape(bool unicode = true,
			  bool html = false,
			  bool attribute = false)
  (HTMLString s) {
  if(s.length == 0) return s;

  import std.array: appender;
  import std.algorithm.iteration: splitter;
  import std.ascii: isPrintable, isWhite;

  bool criteria(const(dchar) c) {
	static if(unicode) {
	  // break on utf-8 multibyte characters, or control characters.

	  foreach(e;EnumMembers!NamedEscapes) {
		if(e.to!dchar == c) return true;
	  }
	}
	static if(html) {
	  foreach(e;EnumMembers!HTMLEscapes) {
		if(e.to!dchar == c) return true;
	  }
	}
	static if(attribute) {
	  foreach(e;EnumMembers!AttributeEscapes) {
		if(e.to!dchar == c) return true;
	  }
	}
	return false;
  }

  auto app = appender!HTMLString;
  /* it's fastest to just iterate over the bytes...
	 because we can't memchr since we don't know what we're looking for.
  */
  int last = 0;
  for(int i=0;i<s.length;++i) {
	HTMLString derp = null;
	bool handle() {
	  static if(html) {
		if(escapeEnum!HTMLEscapes(s[i], derp)) return true;
	  }
	  static if(attribute) {
		if(escapeEnum!AttributeEscapes(s[i], derp)) return true;
	  }
	  static if(!unicode) {
		return false;
	  }
	  if(escapeEnum!NamedEscapes(s[i], derp)) return true;
	  if(isPrintable(s[i])) return false;
	  if(isWhite(s[i])) return false;
	  if(s[i] < 0x7f) {
		derp = "&x"
		  ~ to!string(to!byte(s[i]),0x10)
		  ~ ";";
		return true;
	  }
	  size_t num = 0;
	  import std.utf: decode;
	  import std.algorithm.comparison: min;
	  try {
		auto point = decode(s[i..min($,i+4)],num);
		i += num; // auto-++
		derp = "&x"
		  ~ to!string(to!uint(point),0x10)
		  ~ ";";
		last = i + 1;
	  } catch(Exception e) {
		writeln(s[i-1..min($,i+4)]);
		throw e;
	  }
	  return true;
	}
	if(handle()) {
	  if(last < i) {
		app.put(s[last..i]);
	  }
	  last = i + 1;
	  app.put(derp);
	}
  }
  if(last < s.length) {
	app.put(s[last..$]);
  }
  return app.data;
}

void assert_equal(T)(T a, T b) {
  if(a != b) {
	import std.stdio;
	writeln("ugggh ");
	writeln(a);
	assert(false);
  }
}

unittest {
  assert_equal(escape!(true,true,true)
			   (`<hi>

--—--`),
			   `&lt;hi&gt;

--&x2014;--`);

}
