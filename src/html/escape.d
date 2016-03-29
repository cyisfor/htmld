module html.escape;

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
  nbsp = ' '
}

bool checkEnum(alias Escapes, bool escape = true)
  (string ref chunk,
   Appender!string ref app) {
  import std.traits: EnumMembers;
  import std.conv: to;
  foreach(e;EnumMembers!Escapes) {
	auto repr = e.to!dchar.to!string;
	auto name = e.to!string;
	if(repr == "\"")
	  repr = "\\\"";
	static if(escape == true) {
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
  import std.stdio;
  writeln(checkEnum!(HTMLEscapes,false)(s,app));

  foreach(chunk; chunks) {
	writeln(chunk);
	if(chunk.length == 0) {
	  app.put("&");
	  continue;
	}
	static if(html) {
	  if(checkEnum!(HTMLEscapes,false)(s,app)) continue;
	}
	static if(attribute) {
	  if(checkEnum!(AttributeEscapes,false)(s,app)) continue;
	}
	static if(unicode) {
	  if(checkEnum!(NamedEscapes, false)(s,app)) continue;
	  switch(chunk[0]) {
	  case '#':
		auto pos = chunk.countUntil(';');
		if(pos < 0) {
		  app.put("&" ~ chunk);
		  continue;
		}
		auto num = chunk[1..pos];
		if(!isNumeric(num)) {
		  app.put("&" ~ chunk);
		  continue;
		}
		app.put(num.to!int.to!dchar.to!string);
		app.put(chunk[pos..$]);
		continue;

	  case 'x':
		auto pos = chunk.countUntil(';');
		if(pos < 0) {
		  app.put("&" ~ chunk);
		  continue;
		}
		auto num = chunk[1..pos];
		if(num.count("abcdefABCDEF0123456789") < num.length) {
		  app.put("&" ~ chunk);
		  continue;
		}
		app.put(to!int(num,0x10).to!dchar.to!string);
		continue;
	  default:
		app.put("&" ~ chunk);
		continue;
	  }
	}
  }
  return app.data;
}

unittest {
  import std.stdio;
  writeln("hmmm ",unescape!(true,true,true)("&lt;html&gt;&amp;amp; &#160; &x37;"));
}
