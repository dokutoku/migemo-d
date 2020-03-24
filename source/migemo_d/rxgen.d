/*
 * rxgen.c - regular expression generator
 *
 * Written By:  MURAOKA Taro <koron@tka.att.ne.jp>
 * Last Change: 19-Sep-2009.
 */
module migemo_d.rxgen;


private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import core.stdc.string;
private static import migemo_d.wordbuf;

public alias rxgen_proc_char2int = extern (C) nothrow @nogc int function(const (char)*, uint*);
public alias rxgen_proc_int2char = extern (C) nothrow @nogc int function(uint, char*);
public alias RXGEN_PROC_CHAR2INT = .rxgen_proc_char2int;
public alias RXGEN_PROC_INT2CHAR = .rxgen_proc_int2char;

/* for rxgen_set_operator */
public enum RXGEN_OPINDEX_OR = 0;
public enum RXGEN_OPINDEX_NEST_IN = 1;
public enum RXGEN_OPINDEX_NEST_OUT = 2;
public enum RXGEN_OPINDEX_SELECT_IN = 3;
public enum RXGEN_OPINDEX_SELECT_OUT = 4;
public enum RXGEN_OPINDEX_NEWLINE = 5;
version = RXGEN_ENC_SJISTINY;
//version = RXGEN_OP_VIM;

enum RXGEN_OP_MAXLEN = 8;
enum RXGEN_OP_OR = "|\0";
enum RXGEN_OP_NEST_IN = "(\0";
enum RXGEN_OP_NEST_OUT = ")\0";
enum RXGEN_OP_SELECT_IN = "[\0";
enum RXGEN_OP_SELECT_OUT = "]\0";
enum RXGEN_OP_NEWLINE = "\n\0";

public int n_rnode_new = 0;
public int n_rnode_delete = 0;

extern (C)
struct _rxgen
{
	.rnode* node;
	.RXGEN_PROC_CHAR2INT char2int;
	.RXGEN_PROC_INT2CHAR int2char;
	char[.RXGEN_OP_MAXLEN] op_or;
	char[.RXGEN_OP_MAXLEN] op_nest_in;
	char[.RXGEN_OP_MAXLEN] op_nest_out;
	char[.RXGEN_OP_MAXLEN] op_select_in;
	char[.RXGEN_OP_MAXLEN] op_select_out;
	char[.RXGEN_OP_MAXLEN] op_newline;
}

public alias rxgen = ._rxgen;

/*
 * rnode interfaces
 */

struct _rnode
{
	uint code;
	.rnode* child;
	.rnode* next;
}

alias rnode = ._rnode;

nothrow @nogc
package .rnode* rnode_new()

	do
	{
		++.n_rnode_new;

		return cast(.rnode*)(core.stdc.stdlib.calloc(1, .rnode.sizeof));
	}

nothrow @nogc
package void rnode_delete(.rnode* node)

	do
	{
		while (node != null) {
			.rnode* child = node.child;

			if (node.next != null) {
				.rnode_delete(node.next);
				node.next = null;
			}

			core.stdc.stdlib.free(node);
			node = child;
			++.n_rnode_delete;
		}
	}

/*
 * rxgen interfaces
 */

extern (C)
pure nothrow @trusted @nogc
package int default_char2int(const char* in_, uint* out_)

	in
	{
		assert(in_ != null);
	}

	do
	{
		if (out_ != null) {
			*out_ = *in_;
		}

		return 1;
	}

extern (C)
pure nothrow @nogc
package int default_int2char(uint in_, char* out_)

	do
	{
		int len = 0;

		/* outは最低でも16バイトはある、という仮定を置く */
		switch (in_) {
			case '\\':
			case '.':
			case '*':
			case '^':
			case '$':
			case '/':

			version (RXGEN_OP_VIM) {
				case '[':
				case ']':
				case '~':
			}

				if (out_ != null) {
					out_[len] = '\\';
				}

				++len;

				//ToDo: FALLTHROUGH?
				goto default;

			default:
				if (out_ != null) {
					out_[len] = cast(char)(in_ & 0xFF);
				}

				++len;

				break;
		}

		return len;
	}

extern (C)
nothrow @nogc
public void rxgen_setproc_char2int(.rxgen* object, .RXGEN_PROC_CHAR2INT proc)

	do
	{
		if (object != null) {
			object.char2int = (proc != null) ? (proc) : (&.default_char2int);
		}
	}

extern (C)
nothrow @nogc
public void rxgen_setproc_int2char(.rxgen* object, .RXGEN_PROC_INT2CHAR proc)

	do
	{
		if (object != null) {
			object.int2char = (proc != null) ? (proc) : (&.default_int2char);
		}
	}

nothrow @nogc
package int rxgen_call_char2int(.rxgen* object, const (char)* pch, uint* code)

	do
	{
		int len = object.char2int(pch, code);

		return (len) ? (len) : (.default_char2int(pch, code));
	}

nothrow @nogc
package int rxgen_call_int2char(.rxgen* object, uint code, char* buf)

	do
	{
		int len = object.int2char(code, buf);

		return (len) ? (len) : (.default_int2char(code, buf));
	}

extern (C)
nothrow @nogc
public .rxgen* rxgen_open()

	do
	{
		.rxgen* object = cast(.rxgen*)(core.stdc.stdlib.calloc(1, .rxgen.sizeof));

		if (object != null) {
			.rxgen_setproc_char2int(object, null);
			.rxgen_setproc_int2char(object, null);
			core.stdc.string.strcpy(&(object.op_or[0]), &(.RXGEN_OP_OR[0]));
			core.stdc.string.strcpy(&(object.op_nest_in[0]), &(.RXGEN_OP_NEST_IN[0]));
			core.stdc.string.strcpy(&(object.op_nest_out[0]), &(.RXGEN_OP_NEST_OUT[0]));
			core.stdc.string.strcpy(&(object.op_select_in[0]), &(.RXGEN_OP_SELECT_IN[0]));
			core.stdc.string.strcpy(&(object.op_select_out[0]), &(.RXGEN_OP_SELECT_OUT[0]));
			core.stdc.string.strcpy(&(object.op_newline[0]), &(.RXGEN_OP_NEWLINE[0]));
		}

		return object;
	}

nothrow @nogc
extern (C)
public void rxgen_close(.rxgen* object)

	do
	{
		if (object != null) {
			.rnode_delete(object.node);
			object.node = null;
			core.stdc.stdlib.free(object);
		}
	}

nothrow @nogc
package .rnode* search_rnode(.rnode* node, uint code)

	do
	{
		while ((node != null) && (node.code != code)) {
			node = node.next;
		}

		return node;
	}

extern (C)
nothrow @nogc
public int rxgen_add(.rxgen* object, const (char)* word)

	do
	{
		if ((object == null) || (word == null)) {
			return 0;
		}

		.rnode** ppnode = &object.node;
		uint code;

		while (true) {
			int len = .rxgen_call_char2int(object, word, &code);
			/*core.stdc.stdio.printf("rxgen_call_char2int: code=%08x\n", code);*/

			/* 入力パターンが尽きたら終了 */
			if (code == 0) {
				/* 入力パターンよりも長い既存パターンは破棄する */
				if (*ppnode) {
					.rnode_delete(*ppnode);
					*ppnode = null;
				}

				break;
			}

			.rnode* pnode = .search_rnode(*ppnode, code);

			if (pnode == null) {
				/* codeを持つノードが無い場合、作成追加する */
				pnode = .rnode_new();
				pnode.code = code;
				pnode.next = *ppnode;
				*ppnode = pnode;
			} else if (pnode.child == null) {
				/*
				 * codeを持つノードは有るが、その子供が無い場合、それ以降の入力
				 * パターンは破棄する。例:
				 *     あかい + あかるい . あか
				 *	   たのしい + たのしみ . たのし
				 */
				break;
			}

			/* 子ノードを辿って深い方へ注視点を移動 */
			ppnode = &pnode.child;
			word += len;
		}

		return 1;
	}

nothrow @nogc
package void rxgen_generate_stub(.rxgen* object, migemo_d.wordbuf.wordbuf_t* buf, .rnode* node)

	in
	{
		assert(node != null);
	}

	do
	{
		int haschild = 0;
		int brother = 1;
		.rnode* tmp;

		/* 現在の階層の特性(兄弟の数、子供の数)をチェックする */
		for (tmp = node; tmp; tmp = tmp.next) {
			if (tmp.next != null) {
				++brother;
			}

			if (tmp.child != null) {
				++haschild;
			}
		}

		int nochild = brother - haschild;

		/* For debug */
		version (none) {
			core.stdc.stdio.printf("node=%p code=%04X\n  nochild=%d haschild=%d brother=%d\n", node, node.code, nochild, haschild, brother);
		}

		/* 必要ならば()によるグルーピング */
		if ((brother > 1) && (haschild > 0)) {
			migemo_d.wordbuf.wordbuf_cat(buf, &(object.op_nest_in[0]));
		}

		char[16] ch;

		version (all) {
			/* 子の無いノードを先に[]によりグルーピング */
			if (nochild > 0) {
				if (nochild > 1) {
					migemo_d.wordbuf.wordbuf_cat(buf, &(object.op_select_in[0]));
				}

				for (tmp = node; tmp; tmp = tmp.next) {
					if (tmp.child != null) {
						continue;
					}

					int chlen = .rxgen_call_int2char(object, tmp.code, &(ch[0]));
					ch[chlen] = '\0';
					/*core.stdc.stdio.printf("nochild: %s\n", ch);*/
					migemo_d.wordbuf.wordbuf_cat(buf, &(ch[0]));
				}

				if (nochild > 1) {
					migemo_d.wordbuf.wordbuf_cat(buf, &(object.op_select_out[0]));
				}
			}
		}

		version (all) {
			/* 子のあるノードを出力 */
			if (haschild > 0) {
				/* グループを出力済みならORで繋ぐ */
				if (nochild > 0) {
					migemo_d.wordbuf.wordbuf_cat(buf, &(object.op_or[0]));
				}

				for (tmp = node; !tmp.child; tmp = tmp.next) {
				}

				while (true) {
					int chlen = .rxgen_call_int2char(object, tmp.code, &(ch[0]));
					/*core.stdc.stdio.printf("code=%04X len=%d\n", tmp.code, chlen);*/
					ch[chlen] = '\0';
					migemo_d.wordbuf.wordbuf_cat(buf, &(ch[0]));

					/* 空白・改行飛ばしのパターンを挿入 */
					if (object.op_newline[0]) {
						migemo_d.wordbuf.wordbuf_cat(buf, &(object.op_newline[0]));
					}

					.rxgen_generate_stub(object, buf, tmp.child);

					for (tmp = tmp.next; (tmp != null) && (tmp.child == null); tmp = tmp.next) {
					}

					if (tmp == null) {
						break;
					}

					if (haschild > 1) {
						migemo_d.wordbuf.wordbuf_cat(buf, &(object.op_or[0]));
					}
				}
			}
		}

		/* 必要ならば()によるグルーピング */
		if ((brother > 1) && (haschild > 0)) {
			migemo_d.wordbuf.wordbuf_cat(buf, &(object.op_nest_out[0]));
		}
	}

extern (C)
nothrow @nogc
public char* rxgen_generate(.rxgen* object)

	do
	{
		char* answer = null;

		if (object != null) {
			migemo_d.wordbuf.wordbuf_t* buf = migemo_d.wordbuf.wordbuf_open();

			scope (exit) {
				if (buf != null) {
					migemo_d.wordbuf.wordbuf_close(buf);
					buf = null;
				}
			}

			if (buf != null) {
				if (object.node != null) {
					.rxgen_generate_stub(object, buf, object.node);
				}

				answer = core.stdc.string.strdup(migemo_d.wordbuf.WORDBUF_GET(buf));
			}
		}

		return answer;
	}

extern (C)
nothrow @nogc
public void rxgen_release(.rxgen* object, char* string_)

	do
	{
		if (string_ != null) {
			core.stdc.stdlib.free(string_);
		}
	}

/**
 * rxgen_add()してきたパターンを全てリセット。
 */
extern (C)
nothrow @nogc
public void rxgen_reset(.rxgen* object)

	in
	{
	}

	do
	{
		if (object != null) {
			.rnode_delete(object.node);
			object.node = null;
		}
	}

pure nothrow @trusted @nogc
package char* rxgen_get_operator_stub(.rxgen* object, int index)

	in
	{
		assert(object != null);
	}

	do
	{
		switch (index) {
			case .RXGEN_OPINDEX_OR:
				return &(object.op_or[0]);

			case .RXGEN_OPINDEX_NEST_IN:
				return &(object.op_nest_in[0]);

			case .RXGEN_OPINDEX_NEST_OUT:
				return &(object.op_nest_out[0]);

			case .RXGEN_OPINDEX_SELECT_IN:
				return &(object.op_select_in[0]);

			case .RXGEN_OPINDEX_SELECT_OUT:
				return &(object.op_select_out[0]);

			case .RXGEN_OPINDEX_NEWLINE:
				return &(object.op_newline[0]);

			default:
				return null;
		}
	}

extern (C)
pure nothrow @trusted @nogc
public const (char)* rxgen_get_operator(.rxgen* object, int index)

	in
	{
	}

	do
	{
		return cast(const (char)*)((object != null) ? (.rxgen_get_operator_stub(object, index)) : (null));
	}

extern (C)
pure nothrow @nogc
public int rxgen_set_operator(.rxgen* object, int index, const (char)* op)

	in
	{
		assert(op != null);
	}

	do
	{
		if (object == null) {
			/* Invalid object */
			return 1;
		}

		if (core.stdc.string.strlen(op) >= .RXGEN_OP_MAXLEN) {
			/* Too long operator */
			return 2;
		}

		char* dest = .rxgen_get_operator_stub(object, index);

		if (dest == null) {
			/* No such an operator */
			return 3;
		}

		core.stdc.string.strcpy(dest, op);

		return 0;
	}

version (none) {
	/*
	 * main
	 */
	/+
	int main(int argc, char** argv)

		in
		{
		}

		do
		{
			.rxgen* prx = .rxgen_open();

			scope (exit) {
				if (prx != null) {
					.rxgen_close(prx);
					prx = null;
				}
			}

			if (prx != null) {
				char[256] buf;

				while ((core.stdc.stdio.gets(buf)) && (!core.stdc.stdio.feof(core.stdc.stdio.stdin))) {
					.rxgen_add(prx, buf);
				}

				char* ans = .rxgen_generate(prx);

				scope (exit) {
					if (ans != null) {
						.rxgen_release(prx, ans);
						ans = null;
					}
				}

				core.stdc.stdio.printf("rxgen=%s\n", ans);
			}

			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "n_rnode_new=%d\n", .n_rnode_new);
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "n_rnode_delete=%d\n", .n_rnode_delete);
		}
	+/
}
