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

import std.string: replace;
import std.format: format;
string makeStubs(string prefix) {
	string s = "";
	void stub(string name, int args) {
		string sargs = "";
		string derpargs = "";
		for(int i=0;i<args;++i) {
			if(sargs != "") {
				sargs ~= ", ";
				derpargs ~= ", ";
			}
			auto arg = "a%d".format(i);
			sargs ~= "HTMLString " ~ arg;
			derpargs ~= arg;
		}
		s ~= q{
			void @name@(@sargs@) {
				@prefix@(@derpargs@);
			}
		}.replace("@name@",name)
			  .replace("@sargs@",sargs)
			  .replace("@derpargs@",derpargs)
			  .replace("@prefix@",prefix);
	}
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
		stub(name,1);
	}
	foreach(name;[
				"onAttrEnd"]) {
		stub(name,0);
	}
	foreach(name;[
				  "onEntity",
				]) {
		stub(name,2);
	}
	return s;
}


struct Builder(Document) {
	DOMBuilder!Document souper;
	this(ref Document document, Node* parent = null) {
		souper = DOMBuilder!Document(document,parent);
	}
	NodeReceiver!Document receiver;
	void onOpenEnd(HTMLString data) {
		souper.onOpenEnd(data);
		receiver.onOpenEnd(souper.element_);
	}
	void onClose(HTMLString data) {
		if(souper.element_) {
			receiver.onClose(souper.element_);
		} else {
			receiver.onCloseText(souper.text_);
		}
		souper.onClose(data);
	}
	void onSelfClosing() {
		if(souper.element_)
			receiver.onSelfClosing(souper.element_);
		souper.onSelfClosing();
	}
	void onDocumentEnd() {
		souper.onDocumentEnd();
		receiver.onDocumentEnd(souper.document_);
	}
	mixin(makeStubs("souper."));
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
			writeln("Uhh ",e);
			assert(e);
			if(e.tag == "img" && e.hasAttr("src")) {
				a.put(e);
			}
		}
		override void onDocumentEnd(Document* d) {
			images = a.data;
		}
	}

	enum parserOptions = ((DOMCreateOptions.Default & DOMCreateOptions.DecodeEntities) ? ParserOptions.DecodeEntities : 0);
	writeln("\n\n\n\n\n\n\n");
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
	foreach(img; c.images) {
		writeln("image: ",img.attr("src"));
	}
}
