/*
 * wordbuf.h -
 *
 * Written By:  MURAOKA Taro <koron.kaoriya@gmail.com>
 * Last Change: 25-Oct-2011.
 */
module migemo_d.wordbuf;


private static import core.stdc.stdlib;
private static import core.stdc.string;

public alias wordbuf_t = ._wordbuf_t;
public alias wordbuf_p = ._wordbuf_t*;

public struct _wordbuf_t
{
	/**
	 * bufに割り当てられているメモリ量 
	 */
	int len;

	char* buf;

	/**
	 * bufに実際に格納している文字列の長さ 
	 */
	int last;
}

debug {
	public int n_wordbuf_open = 0;
	public int n_wordbuf_close = 0;
}

pragma(inline, true)
pure nothrow @trusted @nogc
public char* WORDBUF_GET(.wordbuf_p w)

	in
	{
		assert(w != null);
	}

	do
	{
		return &(w.buf[0]);
	}

pragma(inline, true)
pure nothrow @trusted @nogc
public int WORDBUF_LEN(.wordbuf_p w)

	in
	{
		assert(w != null);
	}

	do
	{
		return w.last;
	}

alias wordbuf_len = .wordbuf_last;

enum WORDLEN_DEF = 64;

extern (C)
nothrow @nogc
public .wordbuf_p wordbuf_open()

	do
	{
		.wordbuf_p p = cast(.wordbuf_p)(core.stdc.stdlib.malloc(.wordbuf_t.sizeof));

		if (p != null) {
			debug {
				++.n_wordbuf_open;
			}

			p.len = .WORDLEN_DEF;
			p.buf = cast(char*)(core.stdc.stdlib.malloc(p.len));
			p.last = 0;
			p.buf[0] = '\0';
		}

		return p;
	}

extern (C)
nothrow @nogc
public void wordbuf_close(.wordbuf_p p)

	in
	{
	}

	do
	{
		if (p != null) {
			debug {
				++.n_wordbuf_close;
			}

			if (p.buf != null) {
				core.stdc.stdlib.free(p.buf);
			}

			core.stdc.stdlib.free(p);
		}
	}

extern (C)
pure nothrow @trusted @nogc
public void wordbuf_reset(.wordbuf_p p)

	in
	{
		assert(p != null);
	}

	do
	{
		p.last = 0;
		p.buf[0] = '\0';
	}

/**
 * wordbuf_extend(.wordbuf_p p, int req_len);
 *	バッファの伸長。エラー時には0が帰る。
 *	高速化のために伸ばすべきかは呼出側で判断する。
 */
nothrow @nogc
package int wordbuf_extend(.wordbuf_p p, int req_len)

	in
	{
		assert(p != null);
	}

	do
	{
		int newlen = p.len * 2;

		while (req_len > newlen) {
			newlen *= 2;
		}

		char* newbuf = cast(char*)(core.stdc.stdlib.realloc(p.buf, newlen));

		if (newbuf == null) {
			/*core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "wordbuf_add(): failed to extend buffer\n");*/
			return 0;
		} else {
			p.len = newlen;
			p.buf = newbuf;

			return req_len;
		}
	}

extern (C)
pure nothrow @trusted @nogc
public int wordbuf_last(.wordbuf_p p)

	in
	{
		assert(p != null);
	}

	do
	{
		return p.last;
	}

extern (C)
nothrow @nogc
public int wordbuf_add(.wordbuf_p p, char ch)

	in
	{
		assert(p != null);
	}

	do
	{
		int newlen = p.last + 2;

		if ((newlen > p.len) && (!.wordbuf_extend(p, newlen))) {
			return 0;
		} else {
			version (LittleEndian) {
				/* リトルエンディアンを仮定するなら使えるが… */
				*(cast(ushort*)(&p.buf[p.last])) = cast(ushort)(ch);
			} else {
				char* buf = p.buf + p.last;

				buf[0] = ch;
				buf[1] = '\0';
			}

			return ++p.last;
		}
	}

extern (C)
nothrow @nogc
public int wordbuf_cat(.wordbuf_p p, const (char)* sz)

	in
	{
		assert(p != null);
	}

	do
	{
		int len = 0;

		if (sz != null) {
			size_t l = core.stdc.string.strlen(sz);
			len = (l < int.max) ? (cast(int)(l)) : (int.max);
		}

		if (len > 0) {
			int newlen = p.last + len + 1;

			if ((newlen > p.len) && (!.wordbuf_extend(p, newlen))) {
				return 0;
			}

			core.stdc.string.memcpy(&p.buf[p.last], sz, len + 1);
			p.last = p.last + len;
		}

		return p.last;
	}

extern (C)
pure nothrow @trusted @nogc
public char* wordbuf_get(.wordbuf_p p)

	in
	{
		assert(p != null);
	}

	do
	{
		return p.buf;
	}
