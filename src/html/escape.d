module html.escape;
import std.traits: EnumMembers;
import std.conv: to;

import html: HTMLString;

enum MandatoryEscapes {
  // justification: if we don't escape &, when we unescape, it could get
  // considered an escape!
  amp = '&'
}

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
  import std.string: isNumeric;
  import std.algorithm.searching: countUntil, count;
  auto app = appender!HTMLString;
  auto chunks = s.splitter("&");
  if(chunks.empty) return s;
  chunks.popFront();
  if(chunks.empty) return s;

  foreach(chunk; chunks) {
	bool handle() {
	  if(chunk.length == 0) return false;
	  if(unescapeEnum!MandatoryEscapes(chunk,app)) return true;
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
  import std.algorithm.comparison: equal;
  void assert_equal(HTMLString a, HTMLString b) {
	if(!equal(a,b)) {
	  import std.stdio;
		
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
  import std.ascii: isPrintable, isWhite;

  auto app = appender!HTMLString;

  /* it's fastest to just iterate over the bytes...
	 because we can't memchr, since we don't know what we're looking for.
  */
  int last = 0;
  for(int i=0;i<s.length;++i) {
	HTMLString derp = null;
	/* We need to remember after the last sequence,
	   before the current sequence, AND after the current sequence
	   for multi-byte UTF-8, the latter two are not the same.
	*/
	size_t sequence_length = 0; 
	bool handle() {
	  if(escapeEnum!MandatoryEscapes(s[i],derp)) return true;
	  static if(html) {
		if(escapeEnum!HTMLEscapes(s[i], derp)) return true;
	  }
	  static if(attribute) {
		if(escapeEnum!AttributeEscapes(s[i], derp)) return true;
	  }
	  static if(unicode) {
		if(escapeEnum!NamedEscapes(s[i], derp)) return true;
		if(isPrintable(s[i])) return false;
		// never escape carriage returns, tabs, etc.
		if(isWhite(s[i])) return false;
		if(s[i] < 0x7f) {
		  // if <0x7F, it cannot be the start of a utf-8 code sequence
		  // it could be a control character though. So escape those too.
		  derp = "&x"
			~ to!string(to!ubyte(s[i]),0x10)
			~ ";";
		  return true;
		}
		import std.utf: decode;
		import std.algorithm.comparison: min;
		try {
		  auto point = decode(s[i..min($,i+4)],sequence_length);
		  derp = "&x"
			~ to!string(to!uint(point),0x10)
			~ ";";
		} catch(Exception e) {
		  import std.stdio;
		  writeln(s[i-1..min($,i+4)]);
		  throw e;
		}
		return true;
	  } else {
		return false;
	  }
	}
	if(handle()) {
	  if(last < i) {
		app.put(s[last..i]);
	  }
	  app.put(derp);
	  if(sequence_length > 0)
		i += sequence_length - 1;
	  last = i + 1;
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

--—--<>`),
			   `&lt;hi&gt;

--&x2014;--&lt;&gt;`);

}

alias escapeHTML = escape!(false,true,false);
alias escapeAttribute = escape!(false,true,true);
alias escapeEntities = escape!(true,false,false);
alias escapeEverything = escape!(true,true,true);

unittest {
  assert_equal(escapeHTML(`<test>—--</te&lt;`),
						  `&lt;test&gt;—--&lt;/te&amp;lt;`);
  }
