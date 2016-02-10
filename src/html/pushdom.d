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

struct Builder(Document) {
	DOMBuilder!Document souper;
	this(ref Document document, Node* parent = null) {
		souper = DOMBuilder!Document(document,parent);
	}
	NodeReceiver receiver;
	override void onOpenEnd(HTMLString data) {
		receiver.onOpenEnd(element_);
		souper.onOpenEnd(data);
	}
	override void onClose(HTMLString data) {
		if(element_) {
			receiver.onClose(element_);
		} else {
			receiver.onCloseText(text_);
		}
		souper.onClose(data);
	}
	override void onSelfClosing() {
		receiver.onSelfClosing(element_);
		souper.onSelfClosing();
	}
	override void onDocumentEnd() {
		souper.onDocumentEnd();
		receiver.onDocumentEnd(document_);
	}
}

unittest {
	import html.dom: createDocument, DOMCreateOptions, ParserOptions;
	import html.parser: parseHTML;
	import std.array: Appender;

	class ImageCollector(Document): NodeReceiver {
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
	auto b = new Builder!Document(document);
	ImageCollector c = new ImageCollector(b);
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
