/*
 * migemo.c -
 *
 * Written By:  MURAOKA Taro <koron@tka.att.ne.jp>
 */
module migemo_d.migemo;


private static import core.memory;
private static import core.stdc.ctype;
private static import core.stdc.stdio;
private static import core.stdc.string;
private static import migemo_d.charset;
private static import migemo_d.filename;
private static import migemo_d.mnode;
private static import migemo_d.romaji;
private static import migemo_d.rxgen;
private static import migemo_d.wordbuf;
private static import migemo_d.wordlist;

//#if defined(_WIN32) && !defined(__MINGW32__) && !defined(__CYGWIN32__)
//	#define MIGEMO_CALLTYPE __stdcall
//#else
//	#define MIGEMO_CALLTYPE
//#endif

public enum MIGEMO_VERSION = "1.3";

/* for migemo_load() */
public enum MIGEMO_DICTID_INVALID = 0;
public enum MIGEMO_DICTID_MIGEMO = 1;
public enum MIGEMO_DICTID_ROMA2HIRA = 2;
public enum MIGEMO_DICTID_HIRA2KATA = 3;
public enum MIGEMO_DICTID_HAN2ZEN = 4;
public enum MIGEMO_DICTID_ZEN2HAN = 5;

/* for migemo_set_operator()/migemo_get_operator().  see: rxgen.h */
public enum MIGEMO_OPINDEX_OR = 0;
public enum MIGEMO_OPINDEX_NEST_IN = 1;
public enum MIGEMO_OPINDEX_NEST_OUT = 2;
public enum MIGEMO_OPINDEX_SELECT_IN = 3;
public enum MIGEMO_OPINDEX_SELECT_OUT = 4;
public enum MIGEMO_OPINDEX_NEWLINE = 5;

/* see: rxgen.h */
public alias MIGEMO_PROC_CHAR2INT = extern (C) nothrow @nogc int function(const (char)*, uint*);
public alias MIGEMO_PROC_INT2CHAR = extern (C) nothrow @nogc int function(uint, char*);

enum DICT_MIGEMO = "migemo-dict";
enum DICT_ROMA2HIRA = "roma2hira.dat";
enum DICT_HIRA2KATA = "hira2kata.dat";
enum DICT_HAN2ZEN = "han2zen.dat";
enum DICT_ZEN2HAN = "zen2han.dat";
enum BUFLEN_DETECT_CHARSET = 4096;

alias MIGEMO_PROC_ADDWORD = extern (C) nothrow @nogc int function(void* data, char* word);

/**
 * migemoオブジェクト
 */
struct _migemo
{
	int enable;
	migemo_d.mnode.mtree_p mtree;
	int charset;
	migemo_d.romaji.romaji* roma2hira;
	migemo_d.romaji.romaji* hira2kata;
	migemo_d.romaji.romaji* han2zen;
	migemo_d.romaji.romaji* zen2han;
	migemo_d.rxgen.rxgen* rx;
	.MIGEMO_PROC_ADDWORD addword;
	migemo_d.charset.CHARSET_PROC_CHAR2INT char2int;
}

/**
 * Migemoオブジェクト。migemo_open()で作成され、migemo_closeで破棄される。
 */
public alias migemo = ._migemo;

static immutable char[] VOWEL_CHARS = "aiueo\0";

pure nothrow @trusted @nogc
private int my_strlen(const (char)* s)

	in
	{
		assert(s != null);
	}

	do
	{
		size_t len = core.stdc.string.strlen(s);

		return (len <= int.max) ? (cast(int)(len)) : (int.max);
	}

nothrow @nogc
package migemo_d.mnode.mtree_p load_mtree_dictionary(migemo_d.mnode.mtree_p mtree, const (char)* dict_file)

	in
	{
		assert(mtree != null);
		assert(dict_file != null);
	}

	do
	{
		core.stdc.stdio.FILE* fp = core.stdc.stdio.fopen(dict_file, "rt");

		if (fp == null) {
			/* Can't find file */
			return null;
		}

		scope (exit) {
			if (fp != null) {
				core.stdc.stdio.fclose(fp);
				fp = null;
			}
		}

		mtree = migemo_d.mnode.mnode_load(mtree, fp);

		return mtree;
	}

nothrow @nogc
package migemo_d.mnode.mtree_p load_mtree_dictionary2(.migemo* obj, const (char)* dict_file)

	in
	{
		assert(obj != null);
	}

	do
	{
		if (obj.charset == migemo_d.charset.CHARSET_NONE) {
			/* 辞書の文字セットにあわせて正規表現生成時の関数を変更する */
			migemo_d.charset.CHARSET_PROC_CHAR2INT char2int = null;
			migemo_d.charset.CHARSET_PROC_INT2CHAR int2char = null;
			obj.charset = migemo_d.charset.charset_detect_file(dict_file);
			migemo_d.charset.charset_getproc(obj.charset, &char2int, &int2char);

			if (char2int != null) {
				.migemo_setproc_char2int(obj, cast(.MIGEMO_PROC_CHAR2INT)(char2int));
				obj.char2int = char2int;
			}

			if (int2char != null) {
				.migemo_setproc_int2char(obj, cast(.MIGEMO_PROC_INT2CHAR)(int2char));
			}
		}

		return .load_mtree_dictionary(obj.mtree, dict_file);
	}

nothrow @nogc
package void dircat(char* buf, const (char)* dir, const (char)* file)

	in
	{
		assert(buf != null);
		assert(dir != null);
		assert(file != null);
	}

	do
	{
		core.stdc.string.strcpy(buf, dir);
		core.stdc.string.strcat(buf, "/");
		core.stdc.string.strcat(buf, file);
	}

/*
 * migemo interfaces
 */

/**
 * Migemoオブジェクトに辞書、またはデータファイルを追加読み込みする。
 * dict_fileは読み込むファイル名を指定する。dict_idは読み込む辞書・データの
 * 種類を指定するもので以下のうちどれか一つを指定する:
 *
 *  <dl>
 *  <dt>MIGEMO_DICTID_MIGEMO</dt>
 *	<dd>mikgemo-dict辞書</dd>
 *  <dt>MIGEMO_DICTID_ROMA2HIRA</dt>
 *	<dd>ローマ字→平仮名変換表</dd>
 *  <dt>MIGEMO_DICTID_HIRA2KATA</dt>
 *	<dd>平仮名→カタカナ変換表</dd>
 *  <dt>MIGEMO_DICTID_HAN2ZEN</dt>
 *	<dd>半角→全角変換表</dd>
 *  <dt>MIGEMO_DICTID_ZEN2HAN</dt>
 *	<dd>全角→半角変換表</dd>
 *  </dl>
 *
 *  戻り値は実際に読み込んだ種類を示し、上記の他に読み込みに失敗したことを示す
 *  次の価が返ることがある。
 *
 *  <dl><dt>MIGEMO_DICTID_INVALID</dt></dl>
 *
 * Params:
 *      obj = Migemoオブジェクト
 *      dict_id = 辞書ファイルの種類
 *      dict_file = 辞書ファイルのパス
 */
//MIGEMO_CALLTYPE
extern (C)
nothrow @nogc
export int migemo_load(.migemo* obj, int dict_id, const (char)* dict_file)

	do
	{
		if ((obj == null) && (dict_file != null)) {
			return .MIGEMO_DICTID_INVALID;
		}

		if (dict_id == .MIGEMO_DICTID_MIGEMO) {
			/* migemo辞書読み込み */
			migemo_d.mnode.mtree_p mtree = .load_mtree_dictionary2(obj, dict_file);

			if (mtree == null) {
				return .MIGEMO_DICTID_INVALID;
			}

			obj.mtree = mtree;
			obj.enable = 1;

			/* Loaded successfully */
			return dict_id;
		} else {
			migemo_d.romaji.romaji* dict;

			switch (dict_id) {
				/* ローマ字辞書読み込み */
				case .MIGEMO_DICTID_ROMA2HIRA:
					dict = obj.roma2hira;

					break;

				/* カタカナ辞書読み込み */
				case .MIGEMO_DICTID_HIRA2KATA:
					dict = obj.hira2kata;

					break;

				/* 半角→全角辞書読み込み */
				case .MIGEMO_DICTID_HAN2ZEN:
					dict = obj.han2zen;

					break;

				/* 半角→全角辞書読み込み */
				case .MIGEMO_DICTID_ZEN2HAN:
					dict = obj.zen2han;

					break;

				default:
					dict = null;

					break;
			}

			if ((dict != null) && (migemo_d.romaji.romaji_load(dict, dict_file) == 0)) {
				return dict_id;
			} else {
				return .MIGEMO_DICTID_INVALID;
			}
		}
	}

/**
 * Migemoオブジェクトを作成する。作成に成功するとオブジェクトが戻り値として
 * 返り、失敗するとNULLが返る。dictで指定したファイルがmigemo-dict辞書として
 * オブジェクト作成時に読み込まれる。辞書と同じディレクトリに:
 *
 *  <dl>
 *  <dt>roma2hira.dat</dt>
 *	<dd>ローマ字→平仮名変換表 </dd>
 *  <dt>hira2kata.dat</dt>
 *	<dd>平仮名→カタカナ変換表 </dd>
 *  <dt>han2zen.dat</dt>
 *	<dd>半角→全角変換表 </dd>
 *  </dl>
 *
 * という名前のファイルが存在すれば、存在したものだけが読み込まれる。dictに
 * NULLを指定した場合には、辞書を含めていかなるファイルも読み込まれない。
 * ファイルはオブジェクト作成後にもmigemo_load()関数を使用することで追加読み
 * 込みができる。
 *
 * Params:
 *      dict = migemo-dict辞書のパス。NULLの時は辞書を読み込まない。
 *
 * Returns: 作成されたMigemoオブジェクト
 */
//MIGEMO_CALLTYPE
extern (C)
nothrow @nogc
export .migemo* migemo_open(const (char)* dict)

	do
	{
		/* migemoオブジェクトと各メンバを構築 */
		.migemo* obj = cast(.migemo*)(core.memory.pureCalloc(1, .migemo.sizeof));

		if (obj == null) {
			return null;
		}

		obj.enable = 0;
		obj.mtree = migemo_d.mnode.mnode_open(null);
		obj.charset = migemo_d.charset.CHARSET_NONE;
		obj.rx = migemo_d.rxgen.rxgen_open();
		obj.roma2hira = migemo_d.romaji.romaji_open();
		obj.hira2kata = migemo_d.romaji.romaji_open();
		obj.han2zen = migemo_d.romaji.romaji_open();
		obj.zen2han = migemo_d.romaji.romaji_open();

		if ((obj.rx == null) || (obj.roma2hira == null) || (obj.hira2kata == null) || (obj.han2zen == null) || (obj.zen2han == null)) {
			.migemo_close(obj);

			return obj = null;
		}

		/* デフォルトmigemo辞書が指定されていたらローマ字とカタカナ辞書も探す */
		if (dict != null) {
			/**
			 *  いい加減な数値 
			 */
			enum _MAX_PATH = 1024;

			char[_MAX_PATH] dir;
			char[_MAX_PATH] roma_dict;
			char[_MAX_PATH] kata_dict;
			char[_MAX_PATH] h2z_dict;
			char[_MAX_PATH] z2h_dict;

			migemo_d.filename.filename_directory(&(dir[0]), dict);
			const (char)* tmp = (core.stdc.string.strlen(&(dir[0]))) ? (&(dir[0])) : (".");
			.dircat(&(roma_dict[0]), tmp, .DICT_ROMA2HIRA);
			.dircat(&(kata_dict[0]), tmp, .DICT_HIRA2KATA);
			.dircat(&(h2z_dict[0]), tmp, .DICT_HAN2ZEN);
			.dircat(&(z2h_dict[0]), tmp, .DICT_ZEN2HAN);

			migemo_d.mnode.mtree_p mtree = .load_mtree_dictionary2(obj, dict);

			if (mtree != null) {
				obj.mtree = mtree;
				obj.enable = 1;
				migemo_d.romaji.romaji_load(obj.roma2hira, &(roma_dict[0]));
				migemo_d.romaji.romaji_load(obj.hira2kata, &(kata_dict[0]));
				migemo_d.romaji.romaji_load(obj.han2zen, &(h2z_dict[0]));
				migemo_d.romaji.romaji_load(obj.zen2han, &(z2h_dict[0]));
			}
		}

		return obj;
	}

/**
 * Migemoオブジェクトを破棄し、使用していたリソースを解放する。
 *
 * Params:
 *      obj = 破棄するMigemoオブジェクト
 */
//MIGEMO_CALLTYPE
extern (C)
nothrow @nogc
export void migemo_close(.migemo* obj)

	do
	{
		if (obj != null) {
			if (obj.zen2han != null) {
				migemo_d.romaji.romaji_close(obj.zen2han);
				obj.zen2han = null;
			}

			if (obj.han2zen != null) {
				migemo_d.romaji.romaji_close(obj.han2zen);
				obj.han2zen = null;
			}

			if (obj.hira2kata != null) {
				migemo_d.romaji.romaji_close(obj.hira2kata);
				obj.hira2kata = null;
			}

			if (obj.roma2hira != null) {
				migemo_d.romaji.romaji_close(obj.roma2hira);
				obj.roma2hira = null;
			}

			if (obj.rx != null) {
				migemo_d.rxgen.rxgen_close(obj.rx);
				obj.rx = null;
			}

			if (obj.mtree != null) {
				migemo_d.mnode.mnode_close(obj.mtree);
				obj.mtree = null;
			}

			core.memory.pureFree(obj);
			obj = null;
		}
	}

/*
 * query version 2
 */

/**
 * mnodeの持つ単語リストを正規表現生成エンジンに入力する。
 */
extern (C)
nothrow @nogc
package void migemo_query_proc(migemo_d.mnode.mnode* p, void* data)

	in
	{
		assert(p != null);
		assert(data != null);
	}

	do
	{
		.migemo* object = cast(.migemo*)(data);

		for (migemo_d.wordlist.wordlist_p list = p.list; list != null; list = list.next) {
			object.addword(object, list.ptr_);
		}
	}

/**
 * バッファを用意してmnodeに再帰で書き込ませる
 */
nothrow @nogc
package void add_mnode_query(.migemo* object, char* query)

	do
	{
		migemo_d.mnode.mnode* pnode = migemo_d.mnode.mnode_query(object.mtree, query);

		if (pnode != null) {
			migemo_d.mnode.mnode_traverse(pnode, &.migemo_query_proc, object);
		}
	}

/**
 * 入力をローマから仮名に変換して検索キーに加える。
 */
nothrow @nogc
package int add_roma(.migemo* object, char* query)

	in
	{
		assert(object != null);
	}

	do
	{
		char* stop;
		char* hira = migemo_d.romaji.romaji_convert(object.roma2hira, query, &stop);

		scope (exit) {
			if (hira != null) {
				/* 平仮名解放 */
				migemo_d.romaji.romaji_release(object.roma2hira, hira);
				hira = null;
			}
		}

		if (stop == null) {
			object.addword(object, hira);
			/* 平仮名による辞書引き */
			.add_mnode_query(object, hira);

			/* 片仮名文字列を生成し候補に加える */
			char* kata = migemo_d.romaji.romaji_convert2(object.hira2kata, hira, null, 0);

			scope (exit) {
				if (kata != null) {
					/* カタカナ解放 */
					migemo_d.romaji.romaji_release(object.hira2kata, kata);
					kata = null;
				}
			}

			object.addword(object, kata);

			/* TODO: 半角カナを生成し候補に加える */
			version (all) {
				char* han = migemo_d.romaji.romaji_convert2(object.zen2han, kata, null, 0);

				scope (exit) {
					if (han != null) {
						migemo_d.romaji.romaji_release(object.zen2han, han);
						han = null;
					}
				}

				object.addword(object, han);
				/*core.stdc.stdio.printf("kata=%s\nhan=%s\n", kata, han);*/
			}

			/* カタカナによる辞書引き */
			.add_mnode_query(object, kata);
		}

		return (stop) ? (1) : (0);
	}

/**
 * ローマ字の末尾に母音を付け加えて、各々を検索キーに加える。
 */
nothrow @nogc
package void add_dubious_vowels(.migemo* object, char* buf, size_t index)

	in
	{
		assert(buf != null);
	}

	do
	{
		for (immutable (char)* ptr_ = &(.VOWEL_CHARS[0]); *ptr_ != '\0'; ++ptr_) {
			buf[index] = *ptr_;
			.add_roma(object, buf);
		}
	}

/**
 * ローマ字変換が不完全だった時に、[aiueo]および"xn"と"xtu"を補って変換して
 * みる。
 */
nothrow @nogc
package void add_dubious_roma(.migemo* object, migemo_d.rxgen.rxgen* rx, char* query)

	in
	{
		assert(query != null);
	}

	do
	{
		size_t len = core.stdc.string.strlen(query);

		/*
		 * ローマ字の末尾のアレンジのためのバッファを確保する。
		 *	    内訳: オリジナルの長さ、NUL、吃音(xtu)、補足母音([aieuo])
		 */
		enum size_t end_buf_len = 1 + 3 + 1;

		if (len == 0) {
			return;
		}

		if (len > (size_t.max - end_buf_len)) {
			return;
		}

		size_t max = len + end_buf_len;
		char* buf = cast(char*)(core.memory.pureMalloc(max));

		if (buf == null) {
			return;
		}

		scope (exit) {
			if (buf != null) {
				core.memory.pureFree(buf);
				buf = null;
			}
		}

		buf[0 .. len] = query[0 .. len];
		core.stdc.string.memset(&buf[len], 0, max - len);

		if (core.stdc.string.strchr(&(.VOWEL_CHARS[0]), buf[len - 1]) == null) {
			.add_dubious_vowels(object, buf, len);

			/* 未確定単語の長さが2未満か、未確定文字の直前が母音ならば… */
			if ((len < 2) || (core.stdc.string.strchr(&(.VOWEL_CHARS[0]), buf[len - 2]) != null)) {
				if (buf[len - 1] == 'n') {
					/* 「ん」を補ってみる */
					buf[len - 1] = 'x';
					buf[len] = 'n';
					.add_roma(object, buf);
				} else {
					/* 「っ{元の子音}{母音}」を補ってみる */
					buf[len + 2] = buf[len - 1];
					buf[len - 1] = 'x';
					buf[len] = 't';
					buf[len + 1] = 'u';
					.add_dubious_vowels(object, buf, len + 3);
				}
			}
		}
	}

/**
 * queryを文節に分解する。文節の切れ目は通常アルファベットの大文字。文節が複
 * 数文字の大文字で始まった文節は非大文字を区切りとする。
 */
nothrow @nogc
package migemo_d.wordlist.wordlist_p parse_query(.migemo* object, const (char)* query)

	in
	{
		assert(object != null);
		assert(query != null);
	}

	do
	{
		const (char)* curr = query;
		migemo_d.wordlist.wordlist_p querylist = null;
		migemo_d.wordlist.wordlist_p* pp = &querylist;

		int len;

		while (true) {
			int sum = 0;

			if ((object.char2int == null) || ((len = object.char2int(curr, null)) < 1)) {
				len = 1;
			}

			const (char)* start = curr;
			int upper = ((len == 1) && (core.stdc.ctype.isupper(*curr)) && (core.stdc.ctype.isupper(curr[1])));
			curr += len;
			sum += len;

			while (true) {
				if ((object.char2int == null) || ((len = object.char2int(curr, null)) < 1)) {
					len = 1;
				}

				if ((*curr == '\0') || ((len == 1) && ((core.stdc.ctype.isupper(*curr) != 0) != upper))) {
					break;
				}

				curr += len;
				sum += len;
			}

			/* 文節を登録する */
			if ((start != null) && (start < curr)) {
				*pp = migemo_d.wordlist.wordlist_open_len(start, sum);
				pp = &(*pp).next;
			}

			if (*curr == '\0') {
				break;
			}
		}

		return querylist;
	}

/**
 * 1つの単語をmigemo変換。引数のチェックは行なわない。
 */
nothrow @nogc
package int query_a_word(.migemo* object, char* query)

	in
	{
		assert(object != null);
		assert(query != null);
	}

	do
	{
		size_t len = core.stdc.string.strlen(query);

		assert(size_t.max > len);

		/* query自信はもちろん候補に加える */
		object.addword(object, query);

		/* queryそのものでの辞書引き */
		char* lower = cast(char*)(core.memory.pureMalloc(len + 1));

		scope (exit) {
			if (lower != null) {
				core.memory.pureFree(lower);
				lower = null;
			}
		}

		if (lower == null) {
			.add_mnode_query(object, query);
		} else {
			int i = 0;
			int step;

			// MBを考慮した大文字→小文字変換
			while (i <= len) {
				if ((object.char2int == null) || ((step = object.char2int(&query[i], null)) < 1)) {
					step = 1;
				}

				if ((step == 1) && (core.stdc.ctype.isupper(query[i]))) {
					lower[i] = cast(char)(core.stdc.ctype.tolower(query[i]));
				} else {
					core.stdc.string.memcpy(&lower[i], &query[i], step);
				}

				i += step;
			}

			.add_mnode_query(object, lower);
		}

		/* queryを全角にして候補に加える */
		char* zen = migemo_d.romaji.romaji_convert2(object.han2zen, query, null, 0);

		scope (exit) {
			if (zen != null) {
				migemo_d.romaji.romaji_release(object.han2zen, zen);
				zen = null;
			}
		}

		if (zen != null) {
			object.addword(object, zen);
		}

		/* queryを半角にして候補に加える */
		char* han = migemo_d.romaji.romaji_convert2(object.zen2han, query, null, 0);

		scope (exit) {
			if (han != null) {
				migemo_d.romaji.romaji_release(object.zen2han, han);
				han = null;
			}
		}

		if (han != null) {
			object.addword(object, han);
		}

		/* 平仮名、カタカナ、及びそれによる辞書引き追加 */
		if (.add_roma(object, query)) {
			.add_dubious_roma(object, object.rx, query);
		}

		return 1;
	}

extern (C)
nothrow @nogc
package int addword_rxgen(void* object, char* word)

	in
	{
		assert(object != null);
	}

	do
	{
		/* 正規表現生成エンジンに追加された単語を表示する */
		/*core.stdc.stdio.printf("addword_rxgen: %s\n", word);*/
		return migemo_d.rxgen.rxgen_add((cast(.migemo*)(object)).rx, word);
	}

/**
 * queryで与えられた文字列(ローマ字)を日本語検索のための正規表現へ変換する。
 * 戻り値は変換された結果の文字列(正規表現)で、使用後は#migemo_release()関数
 * へ渡すことで解放しなければならない。
 *
 * Params:
 *      object = Migemoオブジェクト
 *      query = 問い合わせ文字列
 *
 * Returns: 正規表現文字列。#migemo_release() で解放する必要有り。
 */
//MIGEMO_CALLTYPE
extern (C)
nothrow @nogc
export char* migemo_query(.migemo* object, const (char)* query)

	do
	{
		char* retval = null;

		if ((object != null) && (object.rx != null) && (query != null)) {
			migemo_d.wordlist.wordlist_p querylist = .parse_query(object, query);

			scope (exit) {
				if (querylist != null) {
					migemo_d.wordlist.wordlist_close(querylist);
					querylist = null;
				}
			}

			if (querylist == null) {
				/* 空queryのためエラー */
				return retval;
			}

			migemo_d.wordbuf.wordbuf_p outbuf = migemo_d.wordbuf.wordbuf_open();

			scope (exit) {
				if (outbuf != null) {
					retval = outbuf.buf;
					outbuf.buf = null;
					migemo_d.wordbuf.wordbuf_close(outbuf);
					outbuf = null;
				}
			}

			if (outbuf == null) {
				/* 出力用のメモリ領域不足のためエラー */
				return retval;
			}

			/* 単語群をrxgenオブジェクトに入力し正規表現を得る */
			object.addword = &.addword_rxgen;
			migemo_d.rxgen.rxgen_reset(object.rx);

			for (migemo_d.wordlist.wordlist_p p = querylist; p != null; p = p.next) {
				/*core.stdc.stdio.printf("query=%s\n", p.ptr_);*/
				.query_a_word(object, p.ptr_);

				/* 検索パターン(正規表現)生成 */
				char* answer = migemo_d.rxgen.rxgen_generate(object.rx);

				scope (exit) {
					if (answer != null) {
						migemo_d.rxgen.rxgen_release(object.rx, answer);
						answer = null;
					}
				}

				migemo_d.rxgen.rxgen_reset(object.rx);
				migemo_d.wordbuf.wordbuf_cat(outbuf, answer);
			}
		}

		return retval;
	}

/**
 * 使い終わったmigemo_query()関数で得られた正規表現を解放する。
 *
 * Params:
 *      p = Migemoオブジェクト
 *      string = 正規表現文字列
 */
//MIGEMO_CALLTYPE
extern (C)
pure nothrow @trusted @nogc
export void migemo_release(.migemo* p, char* string_)

	do
	{
		if (string_ != null) {
			core.memory.pureFree(string_);
		}
	}

/**
 * Migemoオブジェクトが生成する正規表現に使用するメタ文字(演算子)を指定す
 * る。indexでどのメタ文字かを指定し、opで置き換える。indexには以下の値が指
 * 定可能である:
 *
 *  <dl>
 *  <dt>MIGEMO_OPINDEX_OR</dt>
 *	<dd>論理和。デフォルトは "|" 。vimで利用する際は "\|" 。</dd>
 *  <dt>MIGEMO_OPINDEX_NEST_IN</dt>
 *	<dd>グルーピングに用いる開き括弧。デフォルトは "(" 。vimではレジスタ
 *	\\1〜\\9に記憶させないようにするために "\%(" を用いる。Perlでも同様の
 *	ことを目論むならば "(?:" が使用可能。</dd>
 *  <dt>MIGEMO_OPINDEX_NEST_OUT</dt>
 *	<dd>グルーピングの終了を表す閉じ括弧。デフォルトでは ")" 。vimでは
 *	"\)" 。</dd>
 *  <dt>MIGEMO_OPINDEX_SELECT_IN</dt>
 *	<dd>選択の開始を表す開き角括弧。デフォルトでは "[" 。</dd>
 *  <dt>MIGEMO_OPINDEX_SELECT_OUT</dt>
 *	<dd>選択の終了を表す閉じ角括弧。デフォルトでは "]" 。</dd>
 *  <dt>MIGEMO_OPINDEX_NEWLINE</dt>
 *	<dd>各文字の間に挿入される「0個以上の空白もしくは改行にマッチする」
 *	パターン。デフォルトでは "" であり設定されない。vimでは "\_s*" を指
 *	定する。</dd>
 *  </dl>
 *
 * デフォルトのメタ文字は特に断りがない限りPerlのそれと同じ意味である。設定
 * に成功すると戻り値は1(0以外)となり、失敗すると0になる。
 *
 * Params:
 *      object = Migemoオブジェクト
 *      index = メタ文字識別子
 *      op = メタ文字文字列
 *
 * Returns: 成功時0以外、失敗時0。
 */
//MIGEMO_CALLTYPE
extern (C)
nothrow @nogc
export int migemo_set_operator(.migemo* object, int index, const (char)* op)

	do
	{
		if (object != null) {
			int retval = migemo_d.rxgen.rxgen_set_operator(object.rx, index, op);

			return (retval) ? (0) : (1);
		} else {
			return 0;
		}
	}

/**
 * Migemoオブジェクトが生成する正規表現に使用しているメタ文字(演算子)を取得
 * する。indexについてはmigemo_set_operator()関数を参照。戻り値にはindexの指
 * 定が正しければメタ文字を格納した文字列へのポインタが、不正であればNULLが
 * 返る。
 *
 * Params:
 *      object = Migemoオブジェクト
 *      index = メタ文字識別子
 *
 * Returns: 現在のメタ文字文字列
 */
//MIGEMO_CALLTYPE
extern (C)
nothrow @nogc
export const (char)* migemo_get_operator(.migemo* object, int index)

	do
	{
		return (object != null) ? (migemo_d.rxgen.rxgen_get_operator(object.rx, index)) : (null);
	}

/**
 * Migemoオブジェクトにコード変換用のプロシージャを設定する。プロシージャに
 * ついての詳細は「型リファレンス」セクションのMIGEMO_PROC_CHAR2INTを参照。
 *
 * Params:
 *      object = Migemoオブジェクト
 *      proc = コード変換用プロシージャ
 */
//MIGEMO_CALLTYPE
extern (C)
nothrow @nogc
export void migemo_setproc_char2int(.migemo* object, .MIGEMO_PROC_CHAR2INT proc)

	do
	{
		if (object != null) {
			migemo_d.rxgen.rxgen_setproc_char2int(object.rx, proc);
		}
	}

/**
 * Migemoオブジェクトにコード変換用のプロシージャを設定する。プロシージャに
 * ついての詳細は「型リファレンス」セクションのMIGEMO_PROC_INT2CHARを参照。
 *
 * Params:
 *      object = Migemoオブジェクト
 *      proc = コード変換用プロシージャ
 */
//MIGEMO_CALLTYPE
extern (C)
nothrow @nogc
export void migemo_setproc_int2char(.migemo* object, .MIGEMO_PROC_INT2CHAR proc)

	do
	{
		if (object != null) {
			migemo_d.rxgen.rxgen_setproc_int2char(object.rx, proc);
		}
	}

/**
 * Migemoオブジェクトにmigemo_dictが読み込めているかをチェックする。有効な
 * migemo_dictを読み込めて内部に変換テーブルが構築できていれば0以外(TRUE)
 * を、構築できていないときには0(FALSE)を返す。
 *
 * Params:
 *      obj = Migemoオブジェクト
 *
 * Returns: 成功時0以外、失敗時0。
 */
//MIGEMO_CALLTYPE
extern (C)
pure nothrow @trusted @nogc
export int migemo_is_enable(.migemo* obj)

	do
	{
		return (obj != null) ? (obj.enable) : (0);
	}

debug {
	/*
	 * 主にデバッグ用の隠し関数
	 */
	//MIGEMO_CALLTYPE
	extern (C)
	nothrow @nogc
	export void migemo_print(.migemo* object)

		do
		{
			if (object != null) {
				migemo_d.mnode.mnode_print(object.mtree, null);
			}
		}
}
