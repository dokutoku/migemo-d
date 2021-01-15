/**
 * main.c - migemoライブラリテストドライバ
 *
 * Written By:  MURAOKA Taro <koron@tka.att.ne.jp>
 * Last Change: 23-Feb-2004.
 */
module migemo_test.main;


private static import core.memory;
private static import core.stdc.stdio;
private static import core.stdc.string;
private static import core.stdc.time;
private static import migemo_d.migemo;
private static import std.format;
private static import std.getopt;
private static import std.string;

enum MIGEMO_ABOUT = "migemo-d - D/Migemo Library " ~ migemo_d.migemo.MIGEMO_VERSION ~ " Driver\0";
enum MIGEMODICT_NAME = "migemo-dict";
enum dict_path1 = "./dict/" ~ .MIGEMODICT_NAME ~ '\0';
enum dict_path2 = "../dict/" ~ .MIGEMODICT_NAME ~ '\0';
enum MIGEMO_SUBDICT_MAX = 8;

nothrow @nogc
int query_loop(migemo_d.migemo.migemo* p, int quiet)

	do
	{
		char[256] buf;

		while (!core.stdc.stdio.feof(core.stdc.stdio.stdin)) {
			if (!quiet) {
				core.stdc.stdio.printf("QUERY: ");
			}

			/* gets()を使っていたがfgets()に変更 */
			if (!core.stdc.stdio.fgets(&(buf[0]), buf.length, core.stdc.stdio.stdin)) {
				if (!quiet) {
					core.stdc.stdio.printf("\n");
				}

				break;
			}

			/* 改行をNUL文字に置き換える */
			char* ans = core.stdc.string.strchr(&(buf[0]), '\n');

			if (ans != null) {
				*ans = '\0';
			}

			ans = migemo_d.migemo.migemo_query(p, &(buf[0]));

			scope (exit) {
				if (ans != null) {
					migemo_d.migemo.migemo_release(p, ans);
					ans = null;
				}
			}

			if (ans != null) {
				core.stdc.stdio.printf((quiet) ? ("%s\n") : ("PATTERN: %s\n"), ans);
			}

			core.stdc.stdio.fflush(core.stdc.stdio.stdout);
		}

		return 0;
	}

int main(string[] argv)

	do
	{
		bool mode_vim = false;
		bool mode_emacs = false;
		bool mode_nonewline = false;
		bool mode_quiet = false;
		string dict = null;
		string[] subdict = null;
		size_t subdict_count = 0;
		migemo_d.migemo.migemo* pmigemo;
		core.stdc.stdio.FILE* fplog = core.stdc.stdio.stdout;
		string word = null;

		scope (exit) {
			if (fplog != core.stdc.stdio.stdout) {
				core.stdc.stdio.fclose(fplog);
				fplog = null;
			}
		}

		auto help_info = std.getopt.getopt
		(
			argv,
			"dict|d", `<dict>	Use a file <dict> for dictionary.`, &dict,
			"subdict|s", std.format.format!(`<dict>	Sub dictionary files. (MAX %d times)`)(.MIGEMO_SUBDICT_MAX), &subdict,
			"quiet|q", `Show no message except results.`, &mode_quiet,
			"vim|v", `Use vim style regexp.`, &mode_vim,
			"emacs|e", `Use emacs style regexp.`, &mode_emacs,
			"nonewline|n", `Don't use newline match.`, &mode_nonewline,
			"word|w", `<word>	Expand a <word> and soon exit.`, &word
		);

		if (help_info.helpWanted) {
			const char* prgname = std.string.toStringz(argv[0]);
			core.stdc.stdio.printf("%s \n\nUSAGE: %s [OPTIONS]\n\n", .MIGEMO_ABOUT.ptr, prgname);
			std.getopt.defaultGetoptPrinter("OPTIONS:", help_info.options);

			return 0;
		}

		if (subdict.length > .MIGEMO_SUBDICT_MAX) {
			subdict.length = .MIGEMO_SUBDICT_MAX;
		}

		version (_PROFILE) {
			fplog = core.stdc.stdio.fopen("exe.log", "wt");
		}

		/* 辞書をカレントディレクトリと1つ上のディレクトリから捜す */
		if (dict == null) {
			pmigemo = migemo_d.migemo.migemo_open(.dict_path1.ptr);

			if ((word == null) && (!mode_quiet)) {
				core.stdc.stdio.fprintf(fplog, "migemo_open(\"%s\")=%p\n", .dict_path1.ptr, pmigemo);
			}

			if ((pmigemo == null) || (!migemo_d.migemo.migemo_is_enable(pmigemo))) {
				/* NULLをcloseしても問題はない */
				migemo_d.migemo.migemo_close(pmigemo);
				pmigemo = null;

				pmigemo = migemo_d.migemo.migemo_open(.dict_path2.ptr);

				if ((word == null) && (!mode_quiet)) {
					core.stdc.stdio.fprintf(fplog, "migemo_open(\"%s\")=%p\n", .dict_path2.ptr, pmigemo);
				}
			}
		} else {
			const char* dict_p = std.string.toStringz(dict);
			pmigemo = migemo_d.migemo.migemo_open(dict_p);

			if ((word == null) && (!mode_quiet)) {
				core.stdc.stdio.fprintf(fplog, "migemo_open(\"%s\")=%p\n", dict_p, pmigemo);
			}
		}

		/* サブ辞書を読み込む */
		if (subdict_count > 0) {
			for (size_t i = 0; i < subdict_count; ++i) {
				if ((subdict[i] == null) || (subdict[0][i] == '\0')) {
					continue;
				}

				const char* subdict_p = std.string.toStringz(subdict[i]);

				int result = migemo_d.migemo.migemo_load(pmigemo, migemo_d.migemo.MIGEMO_DICTID_MIGEMO, subdict_p);

				if ((word == null) && (!mode_quiet)) {
					core.stdc.stdio.fprintf(fplog, "migemo_load(%p, %d, \"%s\")=%d\n", pmigemo, migemo_d.migemo.MIGEMO_DICTID_MIGEMO, subdict_p, result);
				}
			}
		}

		scope (exit) {
			if (pmigemo != null) {
				migemo_d.migemo.migemo_close(pmigemo);
				pmigemo = null;
			}
		}

		if (pmigemo == null) {
			return 1;
		} else {
			if (mode_vim) {
				migemo_d.migemo.migemo_set_operator(pmigemo, migemo_d.migemo.MIGEMO_OPINDEX_OR, "\\|");
				migemo_d.migemo.migemo_set_operator(pmigemo, migemo_d.migemo.MIGEMO_OPINDEX_NEST_IN, "\\%(");
				migemo_d.migemo.migemo_set_operator(pmigemo, migemo_d.migemo.MIGEMO_OPINDEX_NEST_OUT, "\\)");

				if (!mode_nonewline) {
					migemo_d.migemo.migemo_set_operator(pmigemo, migemo_d.migemo.MIGEMO_OPINDEX_NEWLINE, "\\_s*");
				}
			} else if (mode_emacs) {
				migemo_d.migemo.migemo_set_operator(pmigemo, migemo_d.migemo.MIGEMO_OPINDEX_OR, "\\|");
				migemo_d.migemo.migemo_set_operator(pmigemo, migemo_d.migemo.MIGEMO_OPINDEX_NEST_IN, "\\(");
				migemo_d.migemo.migemo_set_operator(pmigemo, migemo_d.migemo.MIGEMO_OPINDEX_NEST_OUT, "\\)");

				if (!mode_nonewline) {
					migemo_d.migemo.migemo_set_operator(pmigemo, migemo_d.migemo.MIGEMO_OPINDEX_NEWLINE, "\\s-*");
				}
			}

			version (_PROFILE) {
				/* プロファイル用 */
				{
					char* ans = migemo_d.migemo.migemo_query(pmigemo, "a");

					if (ans != null) {
						core.stdc.stdio.fprintf(fplog, "  [%s]\n", ans);
						migemo_d.migemo.migemo_release(pmigemo, ans);
						ans = null;
					}

					ans = migemo_d.migemo.migemo_query(pmigemo, "k");

					if (ans != null) {
						core.stdc.stdio.fprintf(fplog, "  [%s]\n", ans);
						migemo_d.migemo.migemo_release(pmigemo, ans);
						ans = null;
					}
				}
			} else {
				if (word != null) {
					char* ans = migemo_d.migemo.migemo_query(pmigemo, std.string.toStringz(word));

					if (ans != null) {
						core.stdc.stdio.fprintf(fplog, ((mode_vim) ? ("%s") : ("%s\n")), ans);
						migemo_d.migemo.migemo_release(pmigemo, ans);
						ans = null;
					}
				} else {
					if (!mode_quiet) {
						core.stdc.stdio.printf("clock()=%f\n", cast(float)(core.stdc.time.clock()) / core.stdc.time.CLOCKS_PER_SEC);
					}

					.query_loop(pmigemo, mode_quiet);
				}
			}
		}

		return 0;
	}
