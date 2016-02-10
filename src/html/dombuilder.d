import dom: Document, Node, DOMBuilder;

struct Builder;

struct ElementReceiver {
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

struct Builder: DOMBuilder!Document {
	ElementReceiver receiver;
	void onOpenEnd(HTMLString data) {
		receiver.onOpenEnd(element_);
		super.onOpenEnd(data);
	}
	void onClose(HTMLString data) {
		super.onClose(data);
		if(element_) {
			receiver.onClose(element_);
		} else {
			receiver.onCloseText(text_);
		}
	}
	void onSelfClosing() {
		super.onSelfClosing();
		receiver.onSelfClosing(element_);
	}
	void onDocumentEnd() {
		super.onDocumentEnd();
		receiver.onDocumentEnd(document_);
	}
}

unittest {
	struct ImageCollector: Receiver {
		Node*[] images;
		Appender!Node*[] a;
		this() {
			a = Appender!Node*[](images);
		}
		void onClose(Node* e) {
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
	for(img; c.images) {
		writeln("image: ",img.getAttr("src"));
	}
}
