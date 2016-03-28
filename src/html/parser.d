module html.parser;


import std.algorithm;
import std.array;
import std.ascii;
import std.conv;
import std.traits;

import html.utils;


private enum ParserStates {
	Text = 1,

	// tags
	PreTagName,
	TagName,
	SelfClosingTag,
	PreClosingTagName,
	ClosingTagName,
	PostClosingTagName,

	//attributes
	PreAttrName,
	AttrName,
	PostAttrName,
	PreAttrValue,
	AttrValueDQ,
	AttrValueSQ,
	AttrValueNQ,

	// decls
	PreDeclaration,
	Declaration,
	ProcessingInstruction,
	PreComment,
	Comment,
	PostComment1,
	PostComment2,

	// cdata
	PreCDATA,
	PreCDATA_C,
	PreCDATA_CD,
	PreCDATA_CDA,
	PreCDATA_CDAT,
	PreCDATA_CDATA,
	CDATA,
	PostCDATA1,
	PostCDATA2,

	// scripts / style
	PreScriptOrStyle,
	PreScript_SC,
	PreScript_SCR,
	PreScript_SCRI,
	PreScript_SCRIP,
	PreScript_SCRIPT,
	PreStyle_ST,
	PreStyle_STY,
	PreStyle_STYL,
	PreStyle_STYLE,
	PreClosingScriptOrStyle,
	ClosingScript_SC,
	ClosingScript_SCR,
	ClosingScript_SCRI,
	ClosingScript_SCRIP,
	ClosingScript_SCRIPT,
	ClosingStyle_ST,
	ClosingStyle_STY,
	ClosingStyle_STYL,
	ClosingStyle_STYLE,
}


private enum ParserTextStates {
	Normal = 0,
	Script,
	Style,
}


enum ParserOptions {
	None = 0,
	Default = None
}


void parseHTML(Handler, size_t options = ParserOptions.Default)(const(char)[] source, ref Handler handler) {
	auto ptr = source.ptr;
	auto end = source.ptr + source.length;
	auto start = ptr;

	ParserStates state = ParserStates.Text;
	ParserStates saved = ParserStates.Text;
	ParserTextStates textState = ParserTextStates.Normal;

	while (ptr != end) {
		final switch(state) with (ParserStates) {
		case Text:
			final switch (textState) with (ParserTextStates) {
			case Normal:
			  while ((ptr != end) && (*ptr != '<'))
				++ptr;
			  break;
			case Script:
			case Style:
				while ((ptr != end) && ((*ptr != '<') || (ptr + 1 == end) || (*(ptr + 1) != '/')))
					++ptr;
			}
			if (ptr == end)
				continue;


			if (start != ptr)
			  handler.onText(start[0..ptr-start]);
			state = PreTagName;
			start = ptr;
			break;

		case PreTagName:
			if (*ptr == '/') {
				state = PreClosingTagName;
			} else if ((*ptr == '>') || isSpace(*ptr) || (textState != ParserTextStates.Normal)) {
				state = Text;
			} else {
				switch (*ptr) {
				case '!':
					state = PreDeclaration;
					start = ptr + 1;
					break;
				case '?':
					state = ProcessingInstruction;
					start = ptr + 1;
					break;
				case '<':
					handler.onText(start[0..ptr-start]);
					start = ptr + 1;
					break;
				default:
					if ((*ptr == 's') || (*ptr == 'S')) {
						state = PreScriptOrStyle;
					} else {
						state = TagName;
					}
					start = ptr;
					break;
				}
			}
			break;

		case PreScriptOrStyle:
			if ((*ptr == 'c') || (*ptr == 'C')) {
				state = PreScript_SC;
			} else if ((*ptr == 't') || (*ptr == 'T')) {
				state = PreStyle_ST;
			} else {
				state = TagName;
				goto case TagName;
			}
			break;

		case TagName:
			while ((ptr != end) && (*ptr != '/') && (*ptr != '>') && !isSpace(*ptr))
				++ptr;
			if (ptr == end)
				continue;

			handler.onOpenStart(start[0..ptr-start]);
			state = PreAttrName;
			continue;

		case PreClosingTagName:
			while ((ptr != end) && isSpace(*ptr))
				++ptr;
			if (ptr == end)
				continue;

			if (*ptr == '>') {
				state = Text;
			} else if (textState != ParserTextStates.Normal) {
				if ((*ptr == 's') || (*ptr == 'S')) {
					state = PreClosingScriptOrStyle;
				} else {
					state = Text;
					continue;
				}
			} else {
				state = ClosingTagName;
				start = ptr;
			}
			break;

		case PreClosingScriptOrStyle:
			if ((textState == ParserTextStates.Script) && ((*ptr == 'c') || (*ptr == 'C'))) {
				state = ClosingScript_SC;
			} else if ((textState == ParserTextStates.Style) && ((*ptr == 't') || (*ptr == 'T'))) {
				state = ClosingStyle_ST;
			} else {
				state = Text;
				goto case Text;
			}
			break;

		case ClosingTagName:
			while ((ptr != end) && (*ptr != '>') && !isSpace(*ptr))
				++ptr;
			if (ptr == end)
				continue;

			handler.onClose(start[0..ptr-start]);
			state = PostClosingTagName;
			continue;

		case PostClosingTagName:
			while ((ptr != end) && (*ptr != '>'))
				++ptr;
			if (ptr == end)
				continue;

			state = Text;
			start = ptr + 1;
			break;

		case SelfClosingTag:
			while ((ptr != end) && (*ptr != '>') && isSpace(*ptr))
				++ptr;
			if (ptr == end)
				continue;

			if (*ptr == '>') {
				handler.onSelfClosing();
				state = Text;
				start = ptr + 1;
			} else {
				state = PreAttrName;
				continue;
			}
			break;

		case PreAttrName:
			while ((ptr != end) && (*ptr != '>') && (*ptr != '/') && isSpace(*ptr))
				++ptr;
			if (ptr == end)
				continue;

			if (*ptr == '>') {
				handler.onOpenEnd(start[0..ptr-start]);
				state = Text;
				start = ptr + 1;
			} else if (*ptr == '/') {
				state = SelfClosingTag;
			} else {
				state = AttrName;
				start = ptr;
			}
			break;

		case AttrName:
			while ((ptr != end) && (*ptr != '=') && (*ptr != '>') && (*ptr != '/') && !isSpace(*ptr))
				++ptr;
			if (ptr == end)
				continue;

			handler.onAttrName(start[0..ptr-start]);
			state = PostAttrName;
			start = ptr;
			continue;

		case PostAttrName:
			while ((ptr != end) && (*ptr != '=') && (*ptr != '>') && (*ptr != '/') && isSpace(*ptr))
				++ptr;
			if (ptr == end)
				continue;

			switch(*ptr) {
			case '=':
				state = PreAttrValue;
				break;
			case '/':
			case '>':
				handler.onAttrEnd();
				state = PreAttrName;
				continue;
			default:
				handler.onAttrEnd();
				state = PreAttrName;
				start = ptr;
				continue;
			}
			break;

		case PreAttrValue:
			while ((ptr != end) && (*ptr != '\"') && (*ptr != '\'') && isSpace(*ptr))
				++ptr;
			if (ptr == end)
				continue;

			switch(*ptr) {
			case '\"':
				state = AttrValueDQ;
				start = ptr + 1;
				break;
			case '\'':
				state = AttrValueSQ;
				start = ptr + 1;
				break;
			default:
				state = AttrValueNQ;
				start = ptr;
				continue;
			}
			break;

		case AttrValueDQ:
		  while ((ptr != end) && (*ptr != '\"'))
			++ptr;
		  
			if (ptr == end)
				continue;

			handler.onAttrValue(start[0..ptr-start]);
			handler.onAttrEnd();
			state = PreAttrName;
			break;

		case AttrValueSQ:
		  while ((ptr != end) && (*ptr != '\''))
			++ptr;

			if (ptr == end)
				continue;

			handler.onAttrValue(start[0..ptr-start]);
			handler.onAttrEnd();
			state = PreAttrName;
			break;

		case AttrValueNQ:
		  while ((ptr != end) && (*ptr != '>') && !isSpace(*ptr))
			++ptr;

			if (ptr == end)
				continue;

			handler.onAttrValue(start[0..ptr-start]);
			handler.onAttrEnd();
			state = PreAttrName;
			continue;

		case PreComment:
			if (*ptr == '-') {
				state = Comment;
				start = ptr + 1;
			} else {
				state = Declaration;
			}
			break;

		case Comment:
			while ((ptr != end) && (*ptr != '-'))
				++ptr;
			if (ptr == end)
				continue;

			state = PostComment1;
			break;

		case PostComment1:
			state = (*ptr == '-') ? PostComment2 : Comment;
			break;

		case PostComment2:
			if (*ptr == '>') {
				handler.onComment(start[0..ptr-start-2]);
				state = Text;
				start = ptr + 1;
			} else if (*ptr != '-') {
				state = Comment;
			}
			break;

		case PreDeclaration:
			switch(*ptr) {
			case '[':
				state = PreCDATA;
				break;
			case '-':
				state = PreComment;
				break;
			default:
				state = Declaration;
				break;
			}
			break;

		case PreCDATA:
			if ((*ptr == 'C') || (*ptr == 'c')) {
				state = PreCDATA_C;
			} else {
				state = Declaration;
				continue;
			}
			break;

		case PreCDATA_C:
			if ((*ptr == 'D') || (*ptr == 'd')) {
				state = PreCDATA_CD;
			} else {
				state = Declaration;
				continue;
			}
			break;

		case PreCDATA_CD:
			if ((*ptr == 'A') || (*ptr == 'a')) {
				state = PreCDATA_CDA;
			} else {
				state = Declaration;
				continue;
			}
			break;

		case PreCDATA_CDA:
			if ((*ptr == 'T') || (*ptr == 't')) {
				state = PreCDATA_CDAT;
			} else {
				state = Declaration;
				continue;
			}
			break;

		case PreCDATA_CDAT:
			if ((*ptr == 'A') || (*ptr == 'a')) {
				state = PreCDATA_CDATA;
			} else {
				state = Declaration;
				continue;
			}
			break;

		case PreCDATA_CDATA:
			if (*ptr == '[') {
				state = CDATA;
				start = ptr + 1;
			} else {
				state = Declaration;
				continue;
			}
			break;

		case CDATA:
			while ((ptr != end) && (*ptr != ']'))
				++ptr;
			if (ptr == end)
				continue;

			state = PostCDATA1;
			break;

		case PostCDATA1:
			state = (*ptr == ']') ? PostCDATA2 : CDATA;
			break;

		case PostCDATA2:
			if (*ptr == '>') {
				handler.onCDATA(start[0..ptr-start-2]);
				state = Text;
				start = ptr + 1;
			} else if (*ptr != ']') {
				state = CDATA;
			}
			break;

		case Declaration:
			while ((ptr != end) && (*ptr != '>'))
				++ptr;
			if (ptr == end)
				continue;

			handler.onDeclaration(start[0..ptr-start]);
			state = Text;
			start = ptr + 1;
			break;

		case ProcessingInstruction:
			while ((ptr != end) && (*ptr != '>'))
				++ptr;
			if (ptr == end)
				continue;

			handler.onProcessingInstruction(start[0..ptr-start]);
			state = Text;
			start = ptr + 1;
			break;

		case PreScript_SC:
			if ((*ptr == 'r') || (*ptr == 'R')) {
				state = PreScript_SCR;
			} else {
				state = TagName;
				goto case TagName;
			}
			break;

		case PreScript_SCR:
			if ((*ptr == 'i') || (*ptr == 'I')) {
				state = PreScript_SCRI;
			} else {
				state = TagName;
				goto case TagName;
			}
			break;

		case PreScript_SCRI:
			if ((*ptr == 'p') || (*ptr == 'p')) {
				state = PreScript_SCRIP;
			} else {
				state = TagName;
				goto case TagName;
			}
			break;

		case PreScript_SCRIP:
			if ((*ptr == 't') || (*ptr == 't')) {
				state = PreScript_SCRIPT;
			} else {
				state = TagName;
				goto case TagName;
			}
			break;

		case PreScript_SCRIPT:
			if ((*ptr == '/') || (*ptr == '>') || isSpace(*ptr))
				textState = ParserTextStates.Script;

			state = TagName;
			goto case TagName;

		case PreStyle_ST:
			if ((*ptr == 'y') || (*ptr == 'Y')) {
				state = PreStyle_STY;
			} else {
				state = TagName;
				goto case TagName;
			}
			break;

		case PreStyle_STY:
			if ((*ptr == 'l') || (*ptr == 'L')) {
				state = PreStyle_STYL;
			} else {
				state = TagName;
				goto case TagName;
			}
			break;

		case PreStyle_STYL:
			if ((*ptr == 'e') || (*ptr == 'E')) {
				state = PreStyle_STYLE;
			} else {
				state = TagName;
				goto case TagName;
			}
			break;

		case PreStyle_STYLE:
			if ((*ptr == '/') || (*ptr == '>') || isSpace(*ptr))
				textState = ParserTextStates.Style;

			state = TagName;
			goto case TagName;

		case ClosingScript_SC:
			if ((*ptr == 'r') || (*ptr == 'R')) {
				state = ClosingScript_SCR;
			} else {
				state = Text;
				goto case Text;
			}
			break;

		case ClosingScript_SCR:
			if ((*ptr == 'i') || (*ptr == 'I')) {
				state = ClosingScript_SCRI;
			} else {
				state = Text;
				goto case Text;
			}
			break;

		case ClosingScript_SCRI:
			if ((*ptr == 'p') || (*ptr == 'p')) {
				state = ClosingScript_SCRIP;
			} else {
				state = Text;
				goto case Text;
			}
			break;

		case ClosingScript_SCRIP:
			if ((*ptr == 't') || (*ptr == 't')) {
				state = ClosingScript_SCRIPT;
			} else {
				state = Text;
				goto case Text;
			}
			break;

		case ClosingScript_SCRIPT:
			if ((*ptr == '>') || isSpace(*ptr)) {
				textState = ParserTextStates.Normal;
				state = ClosingTagName;
				start += 2;
				continue;
			} else {
				state = Text;
				goto case Text;
			}

		case ClosingStyle_ST:
			if ((*ptr == 'y') || (*ptr == 'Y')) {
				state = ClosingStyle_STY;
			} else {
				state = Text;
				goto case Text;
			}
			break;

		case ClosingStyle_STY:
			if ((*ptr == 'l') || (*ptr == 'L')) {
				state = ClosingStyle_STYL;
			} else {
				state = Text;
				goto case Text;
			}
			break;

		case ClosingStyle_STYL:
			if ((*ptr == 'e') || (*ptr == 'E')) {
				state = ClosingStyle_STYLE;
			} else {
				state = Text;
				goto case Text;
			}
			break;

		case ClosingStyle_STYLE:
			if ((*ptr == '>') || isSpace(*ptr)) {
				textState = ParserTextStates.Normal;
				state = ClosingTagName;
				start += 2;
				continue;
			} else {
				state = Text;
				goto case Text;
			}
		}

		++ptr;
	}

	auto remaining = start[0..ptr-start];
	if (!remaining.empty) {
		switch(state) with (ParserStates) {
		case Comment:
			handler.onComment(remaining);
			break;
		case PostComment1:
			handler.onComment(remaining[0..$-1]);
			break;
		case PostComment2:
			handler.onComment(remaining[0..$-2]);
			break;
		default:
			if ((state != TagName) &&
				(state != PreAttrName) &&
				(state != PreAttrValue) &&
				(state != PostAttrName) &&
				(state != AttrName) &&
				(state != AttrValueDQ) &&
				(state != AttrValueSQ) &&
				(state != AttrValueNQ) &&
				(state != ClosingTagName)) {
					handler.onText(remaining);
				}
			break;
		}
	}

	handler.onDocumentEnd();
}
