/*
 * mnode.c - mnode interfaces.
 *
 * Written By:  MURAOKA Taro <koron@tka.att.ne.jp>
 * Last Change: 04-May-2004.
 */
module migemo_d.mnode;


private static import core.stdc.ctype;
private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import migemo_d.wordbuf;
private static import migemo_d.wordlist;

/* ツリーオブジェクト */
public alias mnode = ._mnode;

extern (C)
public struct _mnode
{
	uint attr;
	.mnode* next;
	.mnode* child;
	migemo_d.wordlist.wordlist_p list;
}

public enum MNODE_MASK_CH = 0x000000FF;

pragma(inline, true)
pure nothrow @trusted @nogc
public char MNODE_GET_CH(.mnode* p)

	in
	{
		assert(p != null);
	}

	do
	{
		return cast(char)(p.attr);
	}

pragma(inline, true)
pure nothrow @trusted @nogc
public void MNODE_SET_CH(.mnode* p, uint c)

	in
	{
		assert(p != null);
	}

	do
	{
		p.attr = c;
	}

/* for mnode_traverse() */
public alias mnode_traverse_proc = extern (C) nothrow @nogc void function(.mnode* node, void* data);
public alias MNODE_TRAVERSE_PROC = .mnode_traverse_proc;

public int n_mnode_new = 0;
public int n_mnode_delete = 0;

enum MTREE_MNODE_N = 1024;

extern (C)
struct _mtree_t
{
	.mtree_p active;
	int used;
	.mnode[.MTREE_MNODE_N] nodes;
	.mtree_p next;
}

public alias mtree_t = ._mtree_t;
public alias mtree_p = ._mtree_t*;

enum MNODE_BUFSIZE = 16384;

pragma(inline, true)
nothrow @nogc
package .mnode* mnode_new(.mtree_p mtree)

	in
	{
		assert(mtree != null);
	}

	do
	{
		.mtree_p active = mtree.active;

		if (active.used >= .MTREE_MNODE_N) {
			active.next = cast(.mtree_p)(core.stdc.stdlib.calloc(1, (*active.next).sizeof));
			/* TODO: エラー処理 */
			mtree.active = active.next;
			active = active.next;
		}

		++.n_mnode_new;

		return &active.nodes[active.used++];
	}

nothrow @nogc
package void mnode_delete(.mnode* p)

	do
	{
		while (p != null) {
			.mnode* child = p.child;

			if (p.list) {
				migemo_d.wordlist.wordlist_close(p.list);
				p.list = null;
			}

			if (p.next != null) {
				.mnode_delete(p.next);
				p.next = null;
			}

			/*core.stdc.stdlib.free(p);*/
			p = child;
			++.n_mnode_delete;
		}
	}

nothrow @nogc
void mnode_print_stub(.mnode* vp, char* p)

	do
	{
		static char[256] buf;

		if (vp == null) {
			return;
		}

		if (p == null) {
			p = &(buf[0]);
		}

		p[0] = .MNODE_GET_CH(vp);
		p[1] = '\0';

		if (vp.list) {
			core.stdc.stdio.printf("%s (list=%p)\n", &(buf[0]), vp.list);
		}

		if (vp.child != null) {
			.mnode_print_stub(vp.child, p + 1);
		}

		if (vp.next != null) {
			.mnode_print_stub(vp.next, p);
		}
	}

extern (C)
nothrow @nogc
public void mnode_print(.mtree_p mtree, char* p)

	do
	{
		if ((mtree != null) && (mtree.used > 0)) {
			.mnode_print_stub(&mtree.nodes[0], p);
		}
	}

extern (C)
nothrow @nogc
public void mnode_close(.mtree_p mtree)

	in
	{
	}

	do
	{
		if (mtree != null) {
			if (mtree.used > 0) {
				.mnode_delete(&mtree.nodes[0]);
			}

			while (mtree != null) {
				.mtree_p next = mtree.next;
				core.stdc.stdlib.free(mtree);
				mtree = next;
			}
		}
	}

//pragma(inline, true)
nothrow @nogc
package .mnode* search_or_new_mnode(.mtree_p mtree, migemo_d.wordbuf.wordbuf_p buf)

	in
	{
		assert(mtree != null);
		assert(buf != null);
	}

	do
	{
		/* To suppress warning for GCC */
		.mnode** res = null;

		char* word = migemo_d.wordbuf.WORDBUF_GET(buf);
		.mnode* root = (mtree.used > 0) ? (&mtree.nodes[0]) : (null);
		.mnode** ppnext = &root;

		/* ラベル単語が決定したら検索木に追加 */
		int ch;

		while ((ch = *word) != 0) {
			res = ppnext;

			if (!*res) {
				*res = .mnode_new(mtree);
				.MNODE_SET_CH(*res, ch);
			} else if (.MNODE_GET_CH(*res) != ch) {
				ppnext = &(*res).next;

				continue;
			}

			ppnext = &(*res).child;
			++word;
		}

		assert(*res != null);

		return *res;
	}

/**
 * 既存のノードにファイルからデータをまとめて追加する。
 */
extern (C)
nothrow @nogc
public .mtree_p mnode_load(.mtree_p mtree, core.stdc.stdio.FILE* fp)

	do
	{
		/* To suppress warning for GCC */
		migemo_d.wordlist.wordlist_p* ppword = null;

		/* 読み込みバッファ用変数 */
		char[.MNODE_BUFSIZE] cache;
		char* cache_ptr = &(cache[0]);
		char* cache_tail = &(cache[0]);

		migemo_d.wordbuf.wordbuf_p buf = migemo_d.wordbuf.wordbuf_open();
		migemo_d.wordbuf.wordbuf_p prevlabel = migemo_d.wordbuf.wordbuf_open();

		scope (exit) {
			if (buf != null) {
				migemo_d.wordbuf.wordbuf_close(buf);
				buf = null;
			}

			if (prevlabel != null) {
				migemo_d.wordbuf.wordbuf_close(prevlabel);
				prevlabel = null;
			}
		}

		if ((fp == null) || (buf == null) || (prevlabel == null)) {
			return mtree;
		}

		.mnode* pp = null;
		int mode = 0;
		int ch;

		/*
		 * EOFの処理が曖昧。不正な形式のファイルが入った場合を考慮していない。各
		 * モードからEOFの道を用意しないと正しくないが…面倒なのでやらない。デー
		 * タファイルは絶対に間違っていないという前提を置く。
		 */
		do {
			if (cache_ptr >= cache_tail) {
				cache_ptr = &(cache[0]);
				cache_tail = &(cache[0]) + core.stdc.stdio.fread(&(cache[0]), 1, .MNODE_BUFSIZE, fp);
				ch = (((cache_tail <= &(cache[0])) && (core.stdc.stdio.feof(fp)))) ? (core.stdc.stdio.EOF) : (*cache_ptr);
			} else {
				ch = *cache_ptr;
			}

			++cache_ptr;

			/* 状態:modeのオートマトン */
			switch (mode) {
				case 0: /* ラベル単語検索モード */
					/* 空白はラベル単語になりえません */
					if ((core.stdc.ctype.isspace(ch)) || (ch == core.stdc.stdio.EOF)) {
						continue;
					}
					/* コメントラインチェック */
					else if (ch == ';') {
						/* 行末まで食い潰すモード へ移行 */
						mode = 2;

						continue;
					} else {
						/* ラベル単語の読込モード へ移行*/
						mode = 1;

						migemo_d.wordbuf.wordbuf_reset(buf);
						migemo_d.wordbuf.wordbuf_add(buf, cast(char)(ch));
					}

					break;

				case 1: /* ラベル単語の読込モード */
					/* ラベルの終了を検出 */
					switch (ch) {
						default:
							migemo_d.wordbuf.wordbuf_add(buf, cast(char)(ch));

							break;

						case '\t':
							pp = .search_or_new_mnode(mtree, buf);
							migemo_d.wordbuf.wordbuf_reset(buf);

							/* 単語前空白読飛ばしモード へ移行 */
							mode = 3;

							break;
					}

					break;

				case 2: /* 行末まで食い潰すモード */
					if (ch == '\n') {
						migemo_d.wordbuf.wordbuf_reset(buf);

						/* ラベル単語検索モード へ戻る */
						mode = 0;
					}

					break;

				case 3: /* 単語前空白読み飛ばしモード */
					if (ch == '\n') {
						migemo_d.wordbuf.wordbuf_reset(buf);

						/* ラベル単語検索モード へ戻る */
						mode = 0;
					} else if (ch != '\t') {
						/* 単語バッファリセット */
						migemo_d.wordbuf.wordbuf_reset(buf);
						migemo_d.wordbuf.wordbuf_add(buf, cast(char)(ch));
						/* 単語リストの最後を検索(同一ラベルが複数時) */
						ppword = &pp.list;

						while (*ppword != null) {
							ppword = &(*ppword).next;
						}

						/* 単語の読み込みモード へ移行 */
						mode = 4;
					}

					break;

				case 4: /* 単語の読み込みモード */
					switch (ch) {
						case '\t':
						case '\n':
							/* 単語を記憶 */
							*ppword = migemo_d.wordlist.wordlist_open_len(migemo_d.wordbuf.WORDBUF_GET(buf), migemo_d.wordbuf.WORDBUF_LEN(buf));
							migemo_d.wordbuf.wordbuf_reset(buf);

							if (ch == '\t') {
								ppword = &(*ppword).next;

								/* 単語前空白読み飛ばしモード へ戻る */
								mode = 3;
							} else {
								ppword = null;

								/* ラベル単語検索モード へ戻る */
								mode = 0;
							}

							break;

						default:
							migemo_d.wordbuf.wordbuf_add(buf, cast(char)(ch));

							break;
					}

					break;

				default:
					break;
			}
		} while (ch != core.stdc.stdio.EOF);

		return mtree;
	}

extern (C)
nothrow @nogc
public .mtree_p mnode_open(core.stdc.stdio.FILE* fp)

	in
	{
	}

	do
	{
		.mtree_p mtree = cast(.mtree_p)(core.stdc.stdlib.calloc(1, (*mtree).sizeof));
		mtree.active = mtree;

		if ((mtree != null) && (fp != null)) {
			.mnode_load(mtree, fp);
		}

		return mtree;
	}

version (none) {
	pure nothrow @nogc
	package int mnode_size(.mnode* p)

		do
		{
			return (p != null) ? (.mnode_size(p.child) + .mnode_size(p.next) + 1) : (0);
		}
}

pure nothrow @nogc
package .mnode* mnode_query_stub(.mnode* node, const (char)* query)

	in
	{
		assert(node != null);
		assert(query != null);
	}

	do
	{
		while (true) {
			if (*query == .MNODE_GET_CH(node)) {
				return (*++query == '\0') ? (node) : ((node.child != null) ? (.mnode_query_stub(node.child, query)) : (null));
			}

			node = node.next;

			if (node == null) {
				break;
			}
		}

		return null;
	}

extern (C)
pure nothrow @nogc
public .mnode* mnode_query(.mtree_p mtree, const (char)* query)

	do
	{
		return ((query != null) && (*query != '\0') && (mtree != null)) ? (.mnode_query_stub(&mtree.nodes[0], query)) : (null);
	}

nothrow @nogc
package void mnode_traverse_stub(.mnode* node, .MNODE_TRAVERSE_PROC proc, void* data)

	do
	{
		while (true) {
			if (node.child != null) {
				.mnode_traverse_stub(node.child, proc, data);
			}

			proc(node, data);
			node = node.next;

			if (node == null) {
				break;
			}
		}
	}

extern (C)
nothrow @nogc
public void mnode_traverse(.mnode* node, .MNODE_TRAVERSE_PROC proc, void* data)

	do
	{
		if ((node != null) && (proc != null)) {
			proc(node, data);

			if (node.child != null) {
				.mnode_traverse_stub(node.child, proc, data);
			}
		}
	}
