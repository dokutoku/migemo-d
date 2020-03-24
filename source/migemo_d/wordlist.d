/*
 * wordlist.h -
 *
 * Written By:  MURAOKA Taro <koron@tka.att.ne.jp>
 * Last Change: 20-Sep-2009.
 */
module migemo_d.wordlist;


private static import core.stdc.stdlib;
private static import core.stdc.string;

public struct _wordlist_t
{
	char* ptr_;

	deprecated
	alias ptr = ptr_;

	.wordlist_p next;
}

public alias wordlist_t = ._wordlist_t;
public alias wordlist_p = ._wordlist_t*;

public int n_wordlist_open = 0;
public int n_wordlist_close = 0;
public int n_wordlist_total = 0;

extern (C)
nothrow @nogc
public .wordlist_p wordlist_open_len(const char* ptr_, int len)

	do
	{
		if ((ptr_ != null) && (len >= 0)) {
			.wordlist_p p = cast(.wordlist_p)(core.stdc.stdlib.malloc((*p).sizeof + len + 1));

			if (p != null) {
				p.ptr_ = cast(char*)(p + 1);
				p.next = null;
				p.ptr_[0 .. len] = ptr_[0 .. len];
				p.ptr_[len] = '\0';

				++.n_wordlist_open;
				.n_wordlist_total += len;
			}

			return p;
		}

		return null;
	}

extern (C)
nothrow @nogc
public .wordlist_p wordlist_open(const char* ptr_)

	do
	{
		.wordlist_p p;

		if (ptr_ != null) {
			size_t len = core.stdc.string.strlen(ptr_);
			p = .wordlist_open_len(ptr_, ((len < int.max) ? (cast(int)(len)) : (int.max)));
		}

		return p;
	}

extern (C)
nothrow @nogc
public void wordlist_close(.wordlist_p p)

	do
	{
		while (p != null) {
			.wordlist_p next = p.next;

			++.n_wordlist_close;
			core.stdc.stdlib.free(p);
			p = next;
		}
	}
