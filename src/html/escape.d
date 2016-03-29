enum HTMLEscapes {
  lt = '<',
  gt = '>',
};

enum AttributeEscapes {
  quot = '"',
  apos = '\'',
}

string checkEnum(alias Escapes, bool escape = true)(string s) {
  for(e;EnumMembers!Escapes) {
	static if(escape) {
	  app.put(q{
		  if(chunk.startsWith("%1$s")) {
			result.put("&%2$s;");
			result.put(chunk["%1$s".length:$]);
			continue;
		  }
		}.format(to!wchar(e),to!string(e)));
	} else {
	  app.put(q{
		  if(chunk.startsWith("%1$s;")) {
			result.put("%2$s");
			result.put(chunk["%1$s;".length:$]);
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
  (HTMLstring s) {
  appender!HTMLstring result;
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
	  mixin checkEscapes!(HTMLEscapes,false);
	}
	static if(attribute) {
	  mixin checkEscapes!(AttributeEscapes,false);
	}
	static if(unicode) {
	  mixin checkEscapes!(NamedEscapes, false);
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
	  }
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
	default:
	  app.put("&" ~ chunk);
	  continue;
	}
  }
  return app.data;
}

unittest {
  import std.stdio;
  writeln("hmmm ",unescape("&lt;html&gt;&amp;amp; &#160; &x37;"));
}
