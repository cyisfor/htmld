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

bool checkEnum(alias Escapes, bool escape = true)
  (ref HTMLString chunk,
   ref Appender!HTMLString app) {
  import std.string: startsWith;
  foreach(e;EnumMembers!Escapes) {
	auto repr = e.to!dchar.to!string;
	auto name = e.to!string;
	if(repr == "\"")
	  repr = "\\\"";
	static if(escape == true) {
	  writeln("hmm",repr," ",chunk);
	  if(chunk.startsWith(repr)) {
		app.put("&"~name~";");
		app.put(chunk[repr.length..$]);
		return true;
	  }
	} else {
	  if(chunk.startsWith(name ~ ";")) {
		app.put(repr);
		app.put(chunk[name.length+1..$]);
		return true;
	  }
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
	import std.algorithm: min;
	bool handle() {
	  if(chunk.length == 0) return false;
	  static if(html) {
		if(checkEnum!(HTMLEscapes,false)(chunk,app)) return true;
	  }
	  static if(attribute) {
		if(checkEnum!(AttributeEscapes,false)(chunk,app)) return true;
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
		  if(checkEnum!(NamedEscapes, false)(chunk,app)) return true;
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
  import std.ascii: isPrintable;

  bool criteria(const(dchar) c) {
	static if(unicode) {
	  // break on utf-8 multibyte characters, or control characters.
	  if(!isPrintable(c)) return true;
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
	if(!criteria(s[i])) continue;
	if(i > last) {
	  app.put(s[last..i-1]);
	}
	writeln("okay... ",s[i]);
	bool handle() {
	  static if(unicode) {
		import std.utf: decode;
		if(checkEnum!(NamedEscapes, true)(&s[i],app)) return true;
		if(s[i] > 0x7f) {
		  size_t num = 0;
		  auto point = decode(&s[i],num);
		  app.put("&x");
		  app.put(to!string(to!uint(point),0x10));
		  app.put(";");
		  return true;
		}
	  }
	  static if(html) {
		if(checkEnum!(HTMLEscapes, true)(&s[i],app)) return true;
	  }
	  static if(attribute) {
		if(checkEnum!(AttributeEscapes, true)(&s[i],app)) return true;		
	  }
	  return false;
	}
	if(!handle()) {
	  app.put(s[i]);
	}
  }
  return app.data;
}
	
unittest {
  writeln(escape!(true,true,true)(`<hi>

--—--`));
}
