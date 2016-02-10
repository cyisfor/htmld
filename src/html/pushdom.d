module html.pushdom;
import html.dom: Document, Node, DOMBuilder, HTMLString;

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
		this.onClose(element);
	}
	void onDocumentEnd(Document* doc) {}
}

import std.string: replace;
string toIgnore() {
	string s = "";
	foreach(name;["onText",
				  "onOpenStart",
				  "onAttrName",
				  "onAttrEnd",
				  "onAttrValue",
				  "onComment",
				  "onCData",
				  "onDeclaration",
				  "onProcessingInstruction",
				  "onNamedEntity",
				  "onEntity",
				  "onNumericEntity",
				  "onHexEntity",
				  
				]) {
		s ~= q{
			void @name@(HTMLString derp) {
			}
		}.replace("@name@",name);
	}
	foreach(name;[
				"onAttrEnd"]) {
		s ~= q{
			void @name@() {
			}
		}.replace("@name@",name);
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
		receiver.onOpenEnd(souper.element_);
		souper.onOpenEnd(data);
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
		receiver.onSelfClosing(souper.element_);
		souper.onSelfClosing();
	}
	void onDocumentEnd() {
		souper.onDocumentEnd();
		receiver.onDocumentEnd(souper.document_);
	}
	mixin(toIgnore());
}

unittest {
	import html.dom: createDocument, DOMCreateOptions, ParserOptions;
	import html.parser: parseHTML;
	import std.array: Appender;

	class ImageCollector(Document): NodeReceiver!Document {
		Node*[] images;
		Appender!(Node*[]) a;
		this(Builder b) {
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
	import std.stdio: writeln;
	writeln(document.root.html);
	foreach(img; c.images) {
		writeln("image: ",img.attr("src"));
	}
}
