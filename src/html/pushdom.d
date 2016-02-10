module html.pushdom;
import html.dom: Document, Node, DOMBuilder, HTMLString;
	import std.stdio: writeln;

class NodeReceiver(Document) {
	Builder!Document parent;
	this(Builder!Document parent) {
		// for changing parent.receiver
		this.parent = parent;
	}
	void swap(NodeReceiver!Document other) {
		this.parent.receiver = other;
	}
	void onOpenEnd(Node* element) {}
	void onClose(Node* element) {}
	void onCloseText(HTMLString text) {}
	void onSelfClosing(Node* element) {
		if(element)
			this.onClose(element);
	}
	void onDocumentEnd(Document* doc) {}
}

import std.string: replace, strip;
import std.format: format;

immutable string prefix = "souper.";

string stub(string name, int nargs, string block = "@super@") {
	string arg_signature = "";
	string args = "";
	for(int i=0;i<nargs;++i) {
		if(arg_signature != "") {
			arg_signature ~= ", ";
			args ~= ", ";
		}
		auto arg = "a%d".format(i);
		arg_signature ~= "HTMLString " ~ arg;
		args ~= arg;
	}
	block = block.replace("@super@",
						  prefix~name~"("~args~")").strip;
	if(block[$-1] != ';') {
		block ~= ";";
	}
	
	return q{
		void @name@(@arg_signature@) {
			@block@
		}
	}.replace("@name@",name)
		  .replace("@arg_signature@",arg_signature)
		  .replace("@block@",block);
}

string makeBlankStubs() {
	string s = "";

	foreach(name;["onText",
				  "onOpenStart",
				  "onAttrName",
				  "onAttrValue",
				  "onComment",
				  "onCDATA",
				  "onDeclaration",
				  "onProcessingInstruction",
				  "onNamedEntity",
				  "onNumericEntity",
				  "onHexEntity",				  
				]) {
		s ~= stub(name,1);
	}
	foreach(name;[
				"onAttrEnd"]) {
		s ~= stub(name,0);
	}
	foreach(name;[
				  "onEntity",
				]) {
		s ~= stub(name,2);
	}
	return s;
}


struct Builder(Document) {
	DOMBuilder!Document souper;
	this(ref Document document, Node* parent = null) {
		souper = DOMBuilder!Document(document,parent);
	}
	NodeReceiver!Document receiver;
	mixin(stub("onOpenEnd",1,q{
				@super@;
				receiver.onOpenEnd(souper.element_);
			}));
	mixin(stub("onClose",1,q{
		if(souper.element_) {
			receiver.onClose(souper.element_);
		} else {
			receiver.onCloseText(souper.text_);
		}
		@super@;
			}));
	mixin(stub("onSelfClosing",0,q{
		if(souper.element_)
			receiver.onSelfClosing(souper.element_);
		@super@;
			}));
	mixin(stub("onDocumentEnd",0,q{
				@super@;
				receiver.onDocumentEnd(souper.document_);
			}));
	mixin(makeBlankStubs());
}

unittest {
	import html.dom: createDocument, DOMCreateOptions, ParserOptions;
	import html.parser: parseHTML;
	import std.array: Appender;

	class ImageCollector(Document): NodeReceiver!Document {
		Node*[] images;
		Appender!(Node*[]) a;
		this(Builder!Document b) {
			super(b);
		}
		override void onClose(Node* e) {
			if(e.tag == "img" && e.hasAttr("src")) {
				a.put(e);
			}
		}
		override void onDocumentEnd(Document* d) {
			images = a.data;
		}
	}

	enum parserOptions = ((DOMCreateOptions.Default & DOMCreateOptions.DecodeEntities) ? ParserOptions.DecodeEntities : 0);
	auto document = createDocument();
	auto b = Builder!Document(document);
	ImageCollector!Document c = new ImageCollector!Document(b);
	b.receiver = c;
	HTMLString source = `
	<html>
		<head>
		<title>whatever</title>
		</head>
		<body>
			<img src="one.png"/>
			<img src="two.png"/>
			<p>
				 <img src="three.png"/>
			</p>
	    </body>
    </html>`;
	parseHTML!(typeof(b), parserOptions)(source, b);
	writeln(document.root.html);
	string s = "";
	foreach(img; c.images) {
		writeln("image: ",img.attr("src"));
		s ~= img.attr("src");
	}
	assert(s=="one.pngtwo.pngthree.png");
}
