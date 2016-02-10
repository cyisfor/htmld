module html.pushdom;
import html.dom: Document, Node, DOMBuilder, HTMLString;

class NodeReceiver {
	Builder parent;
	this(Builder parent) {
		// for changing parent.receiver
		this.parent = parent;
	}
	void onOpenEnd(Node* element) {}
	void onClose(Node* element) {}
	void onCloseText(HTMLString text) {}
	void onSelfClosing(Node* element) {
		this.onClose(element);
	}
	void onDocumentEnd() {}
}

class Builder: DOMBuilder!Document {
	this(ref Document document, Node* parent = null) {
		super(document,parent);
	}
	NodeReceiver receiver;
	override void onOpenEnd(HTMLString data) {
		receiver.onOpenEnd(element_);
		super.onOpenEnd(data);
	}
	override void onClose(HTMLString data) {
		super.onClose(data);
		if(element_) {
			receiver.onClose(element_);
		} else {
			receiver.onCloseText(text_);
		}
	}
	override void onSelfClosing() {
		super.onSelfClosing();
		receiver.onSelfClosing(element_);
	}
	override void onDocumentEnd() {
		super.onDocumentEnd();
		receiver.onDocumentEnd(document_);
	}
}

unittest {
	import dom: createDocument, DOMCreateOptions, ParserOptions;
	import std.array: Appender;
	
	class ImageCollector: NodeReceiver {
		Node*[] images;
		Appender!(Node*[]) a;
		this() {
			a = Appender!(Node*[])(images);
		}
		override void onClose(Node* e) {
			if(e.tag == "img" && e.hasAttr("src")) {
				a.put(e);
			}
		}
	}

	enum parserOptions = ((DOMCreateOptions.Default & DOMCreateOptions.DecodeEntities) ? ParserOptions.DecodeEntities : 0);

	auto document = createDocument();
	Builder b = Builder(document);
	ImageCollector c = ImageCollector(b);
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
	parseHTML!(typeof(builder), parserOptions)(source, builder);
	writeln(document.html);
	foreach(img; c.images) {
		writeln("image: ",img.getAttr("src"));
	}
}
