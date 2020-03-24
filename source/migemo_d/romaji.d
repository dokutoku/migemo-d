/*
 * romaji.c - ローマ字変換
 *
 * Written By:  MURAOKA Taro <koron@tka.att.ne.jp>
 */
module migemo_d.romaji;


private static import core.stdc.ctype;
private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import core.stdc.string;
private static import migemo_d.charset;
private static import migemo_d.wordbuf;

public alias romaji_proc_char2int = extern (C) nothrow @nogc int function(const (char)*, uint*);
public alias ROMAJI_PROC_CHAR2INT = .romaji_proc_char2int;

enum ROMAJI_FIXKEY_N = 'n';
enum ROMAJI_FIXKEY_XN = "xn";
enum ROMAJI_FIXKEY_XTU = "xtu";
enum ROMAJI_FIXKEY_NONXTU = "aiueon";

/*
 * romanode interfaces
 */

struct _romanode
{
	char key;
	char* value;
	romanode* next;
	romanode* child;
}

alias romanode = ._romanode;

int n_romanode_new = 0;
int n_romanode_delete = 0;

pragma(inline, true)
nothrow @nogc
package .romanode* romanode_new()

	do
	{
		++.n_romanode_new;

		return cast(.romanode*)(core.stdc.stdlib.calloc(1, .romanode.sizeof));
	}

nothrow @nogc
package void romanode_delete(.romanode* node)

	do
	{
		while (node != null) {
			.romanode* child = node.child;

			if (node.next != null) {
				.romanode_delete(node.next);
				node.next = null;
			}

			assert(node.value != null);
			core.stdc.stdlib.free(node.value);
			core.stdc.stdlib.free(node);
			node = child;
			++.n_romanode_delete;
		}
	}

nothrow @nogc
package .romanode** romanode_dig(.romanode** ref_node, const (char)* key)

	do
	{
		if ((ref_node == null) || (key == null) || (key[0] == '\0')) {
			return null;
		}

		while (true) {
			if (!*ref_node) {
				*ref_node = .romanode_new();

				if (*ref_node == null) {
					return null;
				}

				(*ref_node).key = *key;
			}

			if ((*ref_node).key == *key) {
				(*ref_node).value = null;

				if (!*++key) {
					break;
				}

				ref_node = &(*ref_node).child;
			} else {
				ref_node = &(*ref_node).next;
			}
		}

		if ((*ref_node).child) {
			.romanode_delete((*ref_node).child);
			(*ref_node).child = null;
		}

		return ref_node;
	}

/**
 * キーに対応したromanodeを検索して返す。
 *
 * Params:
 *      node = ルートノード
 *      key = 検索キー
 *      skip = 進めるべきkeyのバイト数を受け取るポインタ
 *
 * Returns: romanodeが見つからなかった場合NULL
 */
nothrow @nogc
package .romanode* romanode_query(.romanode* node, const (char)* key, int* skip, .ROMAJI_PROC_CHAR2INT char2int)

	do
	{
		int nskip = 0;
		const (char)* key_start = key;

		// core.stdc.stdio.printf("romanode_query: key=%s skip=%p char2int=%p\n", key, skip, char2int);
		if ((node != null) && (key != null) && (*key)) {
			while (true) {
				if (*key != node.key) {
					node = node.next;
				} else {
					++nskip;

					if (node.value != null) {
						// core.stdc.stdio.printf("  HERE 1\n");

						break;
					}

					if (!*++key) {
						nskip = 0;
						// core.stdc.stdio.printf("  HERE 2\n");

						break;
					}

					node = node.child;
				}

				/* 次に走査するノードが空の場合、キーを進めてNULLを返す */
				if (node == null) {
					/* 1バイトではなく1文字進める */
					if ((char2int == null) || ((nskip = (*char2int)(key_start, null)) < 1)) {
						nskip = 1;
					}

					// core.stdc.stdio.printf("  HERE 3: nskip=%d\n", nskip);

					break;
				}
			}
		}

		if (skip != null) {
			*skip = nskip;
		}

		return node;
	}

version (none) {
	nothrow @nogc
	package void romanode_print_stub(.romanode* node, char* p)

		in
		{
			assert(node != null);
		}

		do
		{
			static char[256] buf;

			if (p == null) {
				p = &(buf[0]);
			}

			p[0] = node.key;
			p[1] = '\0';

			if (node.value != null) {
				core.stdc.stdio.printf("%s=%s\n", &(buf[0]), node.value);
			}

			if (node.child != null) {
				.romanode_print_stub(node.child, p + 1);
			}

			if (node.next != null) {
				.romanode_print_stub(node.next, p);
			}
		}

	nothrow @nogc
	package void romanode_print(.romanode* node)

		do
		{
			if (node == null) {
				return;
			}

			.romanode_print_stub(node, null);
		}
}

/**
 * romaji interface
 */
extern (C)
struct _romaji
{
	int verbose;
	.romanode* node;
	char* fixvalue_xn;
	char* fixvalue_xtu;
	.ROMAJI_PROC_CHAR2INT char2int;
}

public alias romaji = ._romaji;

nothrow @nogc
package char* strdup_lower(const (char)* string_)

	in
	{
		assert(string_ != null);
	}

	do
	{
		char* out_ = core.stdc.string.strdup(string_);

		if (out_ != null) {
			for (char* tmp = out_; *tmp != '\0'; ++tmp) {
				*tmp = cast(char)(core.stdc.ctype.tolower(*tmp));
			}
		}

		return out_;
	}

extern (C)
nothrow @nogc
public .romaji* romaji_open()

	do
	{
		return cast(.romaji*)(core.stdc.stdlib.calloc(1, .romaji.sizeof));
	}

extern (C)
nothrow @nogc
public void romaji_close(.romaji* object)

	do
	{
		if (object != null) {
			if (object.node != null) {
				.romanode_delete(object.node);
				object.node = null;
			}

			if (object.fixvalue_xn != null) {
				core.stdc.stdlib.free(object.fixvalue_xn);
				object.fixvalue_xn = null;
			}

			if (object.fixvalue_xtu != null) {
				core.stdc.stdlib.free(object.fixvalue_xtu);
				object.fixvalue_xtu = null;
			}

			core.stdc.stdlib.free(object);
		}
	}

extern (C)
nothrow @nogc
public int romaji_add_table(.romaji* object, const (char)* key, const (char)* value)

	do
	{
		if ((object == null) || (key == null) || (value == null)) {
			/* Unexpected error */
			return 1;
		}

		size_t value_length = core.stdc.string.strlen(value);

		if (value_length == 0) {
			/* Too short value string */
			return 2;
		}

		.romanode** ref_node = .romanode_dig(&object.node, key);

		if (ref_node == null) {
			/* Memory exhausted */
			return 4;
		}

		debug {
			if (object.verbose >= 10) {
				core.stdc.stdio.printf("romaji_add_table(\"%s\", \"%s\")\n", key, value);
			}
		}

		(*ref_node).value = core.stdc.string.strdup(value);

		/* 「ん」と「っ」は保存しておく */
		if ((object.fixvalue_xn == null) && (value_length > 0) && (!core.stdc.string.strcmp(key, .ROMAJI_FIXKEY_XN))) {
			/*core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "XN: key=%s, value=%s\n", key, value);*/
			object.fixvalue_xn = core.stdc.string.strdup(value);
		}

		if ((object.fixvalue_xtu == null) && (value_length > 0) && (!core.stdc.string.strcmp(key, .ROMAJI_FIXKEY_XTU))) {
			/*core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "XTU: key=%s, value=%s\n", key, value);*/
			object.fixvalue_xtu = core.stdc.string.strdup(value);
		}

		return 0;
	}

nothrow @nogc
int romaji_load_stub(.romaji* object, core.stdc.stdio.FILE* fp)

	do
	{
		migemo_d.wordbuf.wordbuf_p buf_key = migemo_d.wordbuf.wordbuf_open();
		migemo_d.wordbuf.wordbuf_p buf_value = migemo_d.wordbuf.wordbuf_open();

		scope (exit) {
			if (buf_key != null) {
				migemo_d.wordbuf.wordbuf_close(buf_key);
				buf_key = null;
			}

			if (buf_value != null) {
				migemo_d.wordbuf.wordbuf_close(buf_value);
				buf_value = null;
			}
		}

		if ((buf_key == null) || (buf_value == null)) {

			return -1;
		}

		int mode = 0;
		int ch;

		do {
			ch = core.stdc.stdio.fgetc(fp);

			switch (mode) {
				case 0:
					/* key待ちモード */
					if (ch == '#') {
						/* 1文字先読みして空白ならばkeyとして扱う */
						ch = core.stdc.stdio.fgetc(fp);

						if (ch != '#') {
							core.stdc.stdio.ungetc(ch, fp);

							/* 行末まで読み飛ばしモード へ移行 */
							mode = 1;

							break;
						}
					}

					if ((ch != core.stdc.stdio.EOF) && (!core.stdc.ctype.isspace(ch))) {
						migemo_d.wordbuf.wordbuf_reset(buf_key);
						migemo_d.wordbuf.wordbuf_add(buf_key, cast(char)(ch));

						/* key読み込みモード へ移行 */
						mode = 2;
					}

					break;

				case 1:
					/* 行末まで読み飛ばしモード */
					if (ch == '\n') {
						/* key待ちモード へ移行 */
						mode = 0;
					}

					break;

				case 2:
					/* key読み込みモード */
					if (!core.stdc.ctype.isspace(ch)) {
						migemo_d.wordbuf.wordbuf_add(buf_key, cast(char)(ch));
					} else {
						/* value待ちモード へ移行 */
						mode = 3;
					}

					break;

				case 3:
					/* value待ちモード */
					if ((ch != core.stdc.stdio.EOF) && (!core.stdc.ctype.isspace(ch))) {
						migemo_d.wordbuf.wordbuf_reset(buf_value);
						migemo_d.wordbuf.wordbuf_add(buf_value, cast(char)(ch));

						/* value読み込みモード へ移行 */
						mode = 4;
					}

					break;

				case 4:
					/* value読み込みモード */
					if ((ch != core.stdc.stdio.EOF) && (!core.stdc.ctype.isspace(ch))) {
						migemo_d.wordbuf.wordbuf_add(buf_value, cast(char)(ch));
					} else {
						char* key = migemo_d.wordbuf.WORDBUF_GET(buf_key);
						char* value = migemo_d.wordbuf.WORDBUF_GET(buf_value);
						.romaji_add_table(object, key, value);
						mode = 0;
					}

					break;

				default:
					break;
			}
		} while (ch != core.stdc.stdio.EOF);

		return 0;
	}

/**
 * ローマ字辞書を読み込む。
 *
 * Params:
 *      object = ローマ字オブジェクト
 *      filename = 辞書ファイル名
 *
 * Returns: 成功した場合0、失敗した場合は非0を返す。
 */
extern (C)
nothrow @nogc
public int romaji_load(.romaji* object, const (char)* filename)

	do
	{
		if ((object == null) || (filename == null)) {
			return -1;
		}

		version (all) {
			int charset = migemo_d.charset.charset_detect_file(filename);
			migemo_d.charset.charset_getproc(charset,&object.char2int, null);
		}

		core.stdc.stdio.FILE* fp = core.stdc.stdio.fopen(filename, "rt");

		scope (exit) {
			if (fp != null) {
				core.stdc.stdio.fclose(fp);
				fp = null;
			}
		}

		if (fp != null) {
			int result = .romaji_load_stub(object, fp);

			return result;
		} else {
			return -1;
		}
	}

extern (C)
nothrow @nogc
public char* romaji_convert2(.romaji* object, const (char)* string_, char** ppstop, int ignorecase)

	do
	{
		/* Argument "ppstop" receive conversion stoped position. */
		migemo_d.wordbuf.wordbuf_p buf = null;
		char* lower = null;
		char* answer = null;
		const (char)* input = string_;
		int stop = -1;

		if (ignorecase) {
			lower = .strdup_lower(string_);
			input = lower;
		}

		scope (exit) {
			if (lower != null) {
				core.stdc.stdlib.free(lower);
				lower = null;
			}

			if (buf != null) {
				migemo_d.wordbuf.wordbuf_close(buf);
				buf = null;
			}
		}

		if ((object != null) && (string_ != null) && (input != null)) {
			buf = migemo_d.wordbuf.wordbuf_open();

			if (buf != null) {
				int skip;

				for (int i = 0; string_[i];) {
					/* 「っ」の判定 */
					if ((object.fixvalue_xtu != null) && (input[i] == input[i + 1]) && (core.stdc.string.strchr(.ROMAJI_FIXKEY_NONXTU, input[i]) == null)) {
						++i;
						migemo_d.wordbuf.wordbuf_cat(buf, object.fixvalue_xtu);

						continue;
					}

					.romanode* node = .romanode_query(object.node, &input[i], &skip, object.char2int);

					debug {
						if (object.verbose >= 1) {
							core.stdc.stdio.printf("key=%s value=%s skip=%d\n", &input[i], (node != null) ? cast(char*)(node.value) : (&("null\0"[0])), skip);
						}
					}

					if (skip == 0) {
						if (string_[i]) {
							stop = migemo_d.wordbuf.WORDBUF_LEN(buf);
							migemo_d.wordbuf.wordbuf_cat(buf, &string_[i]);
						}

						break;
					} else if (node == null) {
						/* 「n(子音)」を「ん(子音)」に変換 */
						if ((skip == 1) && (input[i] == .ROMAJI_FIXKEY_N) && (object.fixvalue_xn != null)) {
							++i;
							migemo_d.wordbuf.wordbuf_cat(buf, object.fixvalue_xn);
						} else
							while (skip--) {
								migemo_d.wordbuf.wordbuf_add(buf, string_[i++]);
							}
					} else {
						i += skip;
						migemo_d.wordbuf.wordbuf_cat(buf, node.value);
					}
				}

				answer = core.stdc.string.strdup(migemo_d.wordbuf.WORDBUF_GET(buf));
			}
		}

		if (ppstop != null) {
			*ppstop = ((stop >= 0)) ? (answer + stop) : (null);
		}

		return answer;
	}

extern (C)
nothrow @nogc
public char* romaji_convert(.romaji* object, const (char)* string_, char** ppstop)

	do
	{
		return .romaji_convert2(object, string_, ppstop, 1);
	}

extern (C)
nothrow @nogc
public void romaji_release(.romaji* object, char* string_)

	do
	{
		if (string_ != null) {
			core.stdc.stdlib.free(string_);
		}
	}

extern (C)
nothrow @nogc
public void romaji_setproc_char2int(.romaji* object, .ROMAJI_PROC_CHAR2INT proc)

	do
	{
		if (object != null) {
			object.char2int = proc;
		}
	}

extern (C)
nothrow @nogc
public void romaji_set_verbose(.romaji* object, int level)

	do
	{
		if (object != null) {
			object.verbose = level;
		}
	}
