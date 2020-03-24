/*
 * charset.c -
 *
 * Written By:  MURAOKA Taro <koron@tka.att.ne.jp>
 * Last Change: 20-Sep-2009.
 */
module migemo_d.charset;


private static import core.stdc.stdio;

enum BUFLEN_DETECT = 4096;

public enum
{
	CHARSET_NONE = 0,
	CHARSET_CP932 = 1,
	CHARSET_EUCJP = 2,
	CHARSET_UTF8 = 3,
}
	
public alias charset_proc_char2int = extern (C) nothrow @nogc int function(const (char)*, uint*);
public alias charset_proc_int2char = extern (C) nothrow @nogc int function(uint, char*);
public alias CHARSET_PROC_CHAR2INT = .charset_proc_char2int;
public alias CHARSET_PROC_INT2CHAR = .charset_proc_int2char;

extern (C)
pure nothrow @trusted @nogc
public int cp932_char2int(const char* in_, uint* out_)

	in
	{
		assert(in_ != null);
	}

	do
	{
		if ((((0x81 <= in_[0]) && (in_[0] <= 0x9F)) || ((0xE0 <= in_[0]) && (in_[0] <= 0xF0))) && (((0x40 <= in_[1]) && (in_[1] <= 0x7E)) || ((0x80 <= in_[1]) && (in_[1] <= 0xFC)))) {
			if (out_ != null) {
				*out_ = (cast(uint)(in_[0]) << 8) | (cast(uint)(in_[1]));
			}

			return 2;
		} else {
			if (out_ != null) {
				*out_ = in_[0];
			}

			return 1;
		}
	}

extern (C)
pure nothrow @nogc
public int cp932_int2char(uint in_, char* out_)

	do
	{
		if (in_ >= 0x0100) {
			if (out_ != null) {
				out_[0] = cast(char)((in_ >> 8) & 0xFF);
				out_[1] = cast(char)(in_ & 0xFF);
			}

			return 2;
		} else {
			return 0;
		}
	}

pragma(inline, true)
pure nothrow @safe @nogc
bool IS_EUC_RANGE(char c)

	do
	{
		return (0xA1 <= c) && (c <= 0xFE);
	}

extern (C)
pure nothrow @trusted @nogc
public int eucjp_char2int(const char* in_, uint* out_)

	in
	{
		assert(in_ != null);
	}

	do
	{
		if (((in_[0] == 0x8E) && (0xA0 <= in_[1]) && (in_[1] <= 0xDF)) || (.IS_EUC_RANGE(in_[0]) && (.IS_EUC_RANGE(in_[1])))) {
			if (out_ != null) {
				*out_ = cast(uint)(in_[0]) << 8 | cast(uint)(in_[1]);
			}

			return 2;
		} else {
			if (out_ != null) {
				*out_ = in_[0];
			}

			return 1;
		}
	}

extern (C)
pure nothrow @nogc
public int eucjp_int2char(uint in_, char* out_)

	do
	{
		/* CP932と内容は同じだが将来JISX0213に対応させるために分離しておく */
		if (in_ >= 0x0100) {
			if (out_ != null) {
				out_[0] = cast(char)((in_ >> 8) & 0xFF);
				out_[1] = cast(char)(in_ & 0xFF);
			}

			return 2;
		} else {
			return 0;
		}
	}

pure nothrow @trusted @nogc
package int utf8_char2int_noascii(const char* in_, uint* out_)

	in
	{
		assert(in_ != null);
	}

	do
	{
		int len = 0;
		uint ch;

		for (ch = in_[0]; ch & 0x80; ch <<= 1) {
			++len;
		}

		/*core.stdc.stdio.printf("len=%d in_=%s\n", len, in_);*/
		if (len < 2) {
			return 0;
		}

		ch = (ch & 0xFF) >> len;

		for (int i = 1; i < len; ++i) {
			if ((in_[i] & 0xC0) != 0x80) {
				return 0;
			}

			ch <<= 6;
			ch += in_[i] & 0x3F;
		}

		/*core.stdc.stdio.printf("len=%d in_=%s ch=%08x\n", len, in_, ch);*/
		if (out_ != null) {
			*out_ = ch;
		}

		return len;
	}

extern (C)
pure nothrow @trusted @nogc
public int utf8_char2int(const (char)* in_, uint* out_)

	in
	{
		assert(in_ != null);
	}

	do
	{
		int retval = .utf8_char2int_noascii(in_, out_);

		if (retval) {
			return retval;
		} else {
			if (out_ != null) {
				*out_ = in_[0];
			}

			return 1;
		}
	}

extern (C)
pure nothrow @nogc
public int utf8_int2char(uint in_, char* out_)

	in
	{
	}

	do
	{
		if (in_ < 0x80) {
			return 0;
		}

		if (in_ < 0x0800) {
			if (out_ != null) {
				out_[0] = cast(char)(0xC0 + (in_ >> 6));
				out_[1] = 0x80 + ((in_ >> 0) & 0x3F);
			}

			return 2;
		}

		if (in_ < 0x010000) {
			if (out_ != null) {
				out_[0] = cast(char)(0xE0 + (in_ >> 12));
				out_[1] = 0x80 + ((in_ >> 6) & 0x3F);
				out_[2] = 0x80 + ((in_ >> 0) & 0x3F);
			}

			return 3;
		}

		if (in_ < 0x200000) {
			if (out_ != null) {
				out_[0] = cast(char)(0xF0 + (in_ >> 18));
				out_[1] = 0x80 + ((in_ >> 12) & 0x3F);
				out_[2] = 0x80 + ((in_ >> 6) & 0x3F);
				out_[3] = 0x80 + ((in_ >> 0) & 0x3F);
			}

			return 4;
		}

		if (in_ < 0x04000000) {
			if (out_ != null) {
				out_[0] = cast(char)(0xF8 + (in_ >> 24));
				out_[1] = 0x80 + ((in_ >> 18) & 0x3F);
				out_[2] = 0x80 + ((in_ >> 12) & 0x3F);
				out_[3] = 0x80 + ((in_ >> 6) & 0x3F);
				out_[4] = 0x80 + ((in_ >> 0) & 0x3F);
			}

			return 5;
		} else {
			if (out_ != null) {
				out_[0] = 0xF8 + (in_ >> 30);
				out_[1] = 0x80 + ((in_ >> 24) & 0x3F);
				out_[2] = 0x80 + ((in_ >> 18) & 0x3F);
				out_[3] = 0x80 + ((in_ >> 12) & 0x3F);
				out_[4] = 0x80 + ((in_ >> 6) & 0x3F);
				out_[5] = 0x80 + ((in_ >> 0) & 0x3F);
			}

			return 6;
		}
	}

extern (C)
pure nothrow @trusted @nogc
public int charset_detect_buf(const char* buf, int len)

	in
	{
		assert(buf != null);
	}

	do
	{
		int sjis = 0;
		int euc = 0;
		int utf8 = 0;
		int umode = 0;
		bool smode = false;
		bool emode = false;
		bool ufailed = false;

		for (int i = 0; i < len; ++i) {
			char c = buf[i];

			// SJISであるかのチェック
			if (smode) {
				if (((0x40 <= c) && (c <= 0x7E)) || ((0x80 <= c) && (c <= 0xFC))) {
					++sjis;
				}

				smode = false;
			} else if (((0x81 <= c) && (c <= 0x9F)) || ((0xE0 <= c) && (c <= 0xF0))) {
				smode = true;
			}

			// EUCであるかのチェック
			bool eflag = (0xA1 <= c) && (c <= 0xFE);

			if (emode) {
				if (eflag) {
					++euc;
				}

				emode = false;
			} else if (eflag) {
				emode = true;
			}

			// UTF8であるかのチェック
			if (!ufailed) {
				if (umode < 1) {
					if ((c & 0x80) != 0) {
						if ((c & 0xE0) == 0xC0) {
							umode = 1;
						} else if ((c & 0xF0) == 0xE0) {
							umode = 2;
						} else if ((c & 0xF8) == 0xF0) {
							umode = 3;
						} else if ((c & 0xFC) == 0xF8) {
							umode = 4;
						} else if ((c & 0xFE) == 0xFC) {
							umode = 5;
						} else {
							ufailed = true;
							--utf8;
						}
					}
				} else {
					if ((c & 0xC0) == 0x80) {
						++utf8;
						--umode;
					} else {
						--utf8;
						umode = 0;
						ufailed = true;
					}
				}

				if (utf8 < 0) {
					utf8 = 0;
				}
			}
		}

		// 最終的に一番得点の高いエンコードを返す
		if ((euc > sjis) && (euc > utf8)) {
			return .CHARSET_EUCJP;
		} else if ((!ufailed) && (utf8 > euc) && (utf8 > sjis)) {
			return .CHARSET_UTF8;
		} else if ((sjis > euc) && (sjis > utf8)) {
			return .CHARSET_CP932;
		} else {
			return .CHARSET_NONE;
		}
	}

extern (C)
pure nothrow @nogc
public void charset_getproc(int charset, .CHARSET_PROC_CHAR2INT* char2int, .CHARSET_PROC_INT2CHAR* int2char)

	do
	{
		.CHARSET_PROC_CHAR2INT c2i = null;
		.CHARSET_PROC_INT2CHAR i2c = null;

		switch (charset) {
			case .CHARSET_CP932:
				c2i = &.cp932_char2int;
				i2c = &.cp932_int2char;

				break;

			case .CHARSET_EUCJP:
				c2i = &.eucjp_char2int;
				i2c = &.eucjp_int2char;

				break;

			case .CHARSET_UTF8:
				c2i = &.utf8_char2int;
				i2c = &.utf8_int2char;

				break;

			default:
				break;
		}

		if (char2int != null) {
			*char2int = c2i;
		}

		if (int2char != null) {
			*int2char = i2c;
		}
	}

extern (C)
nothrow @nogc
public int charset_detect_file(const (char)* path)

	in
	{
		assert(path != null);
	}

	do
	{
		int charset = .CHARSET_NONE;
		core.stdc.stdio.FILE* fp = core.stdc.stdio.fopen(path, "rt");

		scope (exit) {
			if (fp != null) {
				core.stdc.stdio.fclose(fp);
				fp = null;
			}
		}

		if (fp != null) {
			char[.BUFLEN_DETECT] buf;
			size_t len = core.stdc.stdio.fread(&(buf[0]), buf[0].sizeof, buf.length, fp);

			if ((len > 0) && (len <= int.max)) {
				charset = .charset_detect_buf(&(buf[0]), cast(int)(len));
			}
		}

		return charset;
	}
