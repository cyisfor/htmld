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

string checkEnum(alias Escapes, bool escape = true)(string s) {
  import std.array: appender;
  import std.traits: EnumMembers;
  import std.format: format;
  import std.conv: to;
  auto app = appender!string;
  foreach(e;EnumMembers!Escapes) {
	static if(escape) {
	  app.put(q{
		  if(chunk.startsWith("%1$s")) {
			app.put("&%2$s;");
			app.put(chunk["%1$s".length:$]);
			continue;
		  }
		}.format(to!wchar(e),to!string(e)));
	} else {
	  app.put(q{
		  if(chunk.startsWith("%1$s;")) {
			app.put("%2$s");
			app.put(chunk["%1$s;".length:$]);
			continue;
		  }
		}.format(to!string(e),to!wchar(e)));
	}
  }
  return app.data;
}

auto unescape(bool unicode = true,
			  bool html = false,
			  bool attribute = false)
  (HTMLString s) {
  import std.array: appender;
  import std.algorithm.iteration: splitter;
  import std.conv: to;
  import std.string: isNumeric;
  import std.algorithm.searching: countUntil, count;
  auto app = appender!HTMLString;
  auto chunks = s.splitter("&");
  if(chunks.empty) return s;
  chunks.popFront();
  if(chunks.empty) return s;

  foreach(chunk; chunks) {
	if(chunk.length == 0) {
	  app.put("&");
	  continue;
	}
	static if(html) {
	  mixin checkEnum!(HTMLEscapes,false);
	}
	static if(attribute) {
	  mixin checkEnum!(AttributeEscapes,false);
	}
	static if(unicode) {
	  mixin checkEnum!(NamedEscapes, false);
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
  writeln("hmmm ",unescape("&lt;html&gt;&amp;amp; &#160; &x37;"));
}
