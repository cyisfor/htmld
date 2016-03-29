enum HTMLEscapes {
  lt = '<',
  gt = '>',
};

enum AttributeEscapes {
  quot = '"',
  

string checkEscapes() {
  return q{
	if(chunk.startsWith("%1$s;")) {
	  result.put("%2$s");
	  result.put(chunk["%1$s;".length:$]);
	} else
  }.format(match,replacement);
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
	mixin checkEscape("lt")
	  mixin checkEscape("gt")
	  mixin checkEscape("
	static if(html) {
	  if(chunk.startsWith("lt;"
	  
	
