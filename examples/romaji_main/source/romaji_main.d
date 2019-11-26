/*
 * romaji_main.c -
 *
 * Written By:  MURAOKA Taro <koron@tka.att.ne.jp>
 * Last Change: 21-Sep-2004.
 */
/*
 * gcc -o romaji romaji_main.c ../romaji.c ../wordbuf.c
 */
module romaji_main.romaji_main;


private static import core.stdc.stdio;
private static import core.stdc.string;
private static import migemo_d.romaji;
private static import std.getopt;
private static import std.string;

enum DICTDIR = "../../dict";
enum DICT_ROMA2HIRA = DICTDIR ~ "/roma2hira.dat\0";
enum DICT_HIRA2KATA = DICTDIR ~ "/hira2kata.dat\0";
enum DICT_HAN2ZEN = DICTDIR ~ "/han2zen.dat\0";
enum DICT_ZEN2HAN = DICTDIR ~ "/zen2han.dat\0";

nothrow @nogc
void query_one(migemo_d.romaji.romaji* object, migemo_d.romaji.romaji* hira2kata, migemo_d.romaji.romaji* han2zen, migemo_d.romaji.romaji* zen2han, char* buf)

	do
	{
		/* ローマ字→平仮名(表示)→片仮名(表示) */
		char* stop;
		char* hira = migemo_d.romaji.romaji_convert(object, buf, &stop);

		scope (exit) {
			if (hira != null) {
				migemo_d.romaji.romaji_release(object, hira);
				hira = null;
			}
		}

		if (hira != null) {
			core.stdc.stdio.printf("  hira=%s, stop=%s\n", hira, stop);

			version (all) {
				char* kata = migemo_d.romaji.romaji_convert2(hira2kata, hira, &stop, 0);

				scope (exit) {
					if (kata != null) {
						migemo_d.romaji.romaji_release(hira2kata, kata);
						kata = null;
					}
				}

				if (kata != null) {
					core.stdc.stdio.printf("  kata=%s, stop=%s\n", kata, stop);
					char* han = migemo_d.romaji.romaji_convert2(zen2han, kata, &stop, 0);

					scope (exit) {
						if (han != null) {
							migemo_d.romaji.romaji_release(zen2han, han);
							han = null;
						}
					}

					if (han != null) {
						core.stdc.stdio.printf("  han=%s, stop=%s\n", han, stop);
					}
				}
			}
		}

		version (all) {
			char* zen = migemo_d.romaji.romaji_convert2(han2zen, buf, &stop, 0);

			scope (exit) {
				if (zen != null) {
					migemo_d.romaji.romaji_release(han2zen, zen);
					zen = null;
				}
			}

			if (zen != null) {
				core.stdc.stdio.printf("  zen=%s, stop=%s\n", zen, stop);
			}
		}

		core.stdc.stdio.fflush(core.stdc.stdio.stdout);
	}

nothrow @nogc
void query_loop(migemo_d.romaji.romaji* object, migemo_d.romaji.romaji* hira2kata, migemo_d.romaji.romaji* han2zen, migemo_d.romaji.romaji* zen2han)

	do
	{
		char[256] buf;

		while (true) {
			core.stdc.stdio.printf("QUERY: ");

			if (!core.stdc.stdio.fgets(&(buf[0]), buf.length, core.stdc.stdio.stdin)) {
				core.stdc.stdio.printf("\n");

				break;
			}

			/* 改行をNUL文字に置き換える */
			char* ans = core.stdc.string.strchr(&(buf[0]), '\n');

			if (ans != null) {
				*ans = '\0';
			}

			.query_one(object, hira2kata, han2zen, zen2han, &(buf[0]));
		}
	}

int main(string[] argv)

	do
	{
		migemo_d.romaji.romaji* object = migemo_d.romaji.romaji_open();
		migemo_d.romaji.romaji* hira2kata = migemo_d.romaji.romaji_open();
		migemo_d.romaji.romaji* han2zen = migemo_d.romaji.romaji_open();
		migemo_d.romaji.romaji* zen2han = migemo_d.romaji.romaji_open();

		scope (exit) {
			if (zen2han != null) {
				migemo_d.romaji.romaji_close(zen2han);
				zen2han = null;
			}

			if (han2zen != null) {
				migemo_d.romaji.romaji_close(han2zen);
				han2zen = null;
			}

			if (hira2kata != null) {
				migemo_d.romaji.romaji_close(hira2kata);
				hira2kata = null;
			}

			if (object != null) {
				migemo_d.romaji.romaji_close(object);
				object = null;
			}
		}

		migemo_d.romaji.romaji_set_verbose(zen2han, 1);

		string word = null;

		auto help_info = std.getopt.getopt
		(
			argv,
			"word|w", &word
		);

		if ((object != null) && (hira2kata != null) && (han2zen != null) && (zen2han != null)) {
			int retval = migemo_d.romaji.romaji_load(object, .DICT_ROMA2HIRA.ptr);
			core.stdc.stdio.printf("romaji_load(%s)=%d\n", .DICT_ROMA2HIRA.ptr, retval);
			retval = migemo_d.romaji.romaji_load(hira2kata, .DICT_HIRA2KATA.ptr);
			core.stdc.stdio.printf("romaji_load(%s)=%d\n", .DICT_HIRA2KATA.ptr, retval);
			retval = migemo_d.romaji.romaji_load(han2zen, .DICT_HAN2ZEN.ptr);
			core.stdc.stdio.printf("romaji_load(%s)=%d\n", .DICT_HAN2ZEN.ptr, retval);
			retval = migemo_d.romaji.romaji_load(zen2han, .DICT_ZEN2HAN.ptr);
			core.stdc.stdio.printf("romaji_load(%s)=%d\n", .DICT_HAN2ZEN.ptr, retval);

			if (word != null) {
				.query_one(object, hira2kata, han2zen, zen2han, std.string.toStringz(word));
			} else {
				.query_loop(object, hira2kata, han2zen, zen2han);
			}
		}

		return 0;
	}
