/*
 * rxgen.c - regular expression generator
 *
 * Written By:  MURAOKA Taro <koron@tka.att.ne.jp>
 * Last Change: 19-Sep-2009.
 */
module migemo_d.example.rxgen;


private static import core.stdc.stdio;
private static import migemo_d.rxgen;

extern (C)
nothrow @nogc
int main(int argc, char** argv)

	do
	{
		migemo_d.rxgen.rxgen* prx = migemo_d.rxgen.rxgen_open();

		scope (exit) {
			if (prx != null) {
				migemo_d.rxgen.rxgen_close(prx);
				prx = null;
			}
		}

		if (prx != null) {
			char[256] buf;

			while ((core.stdc.stdio.gets(buf)) && (!core.stdc.stdio.feof(core.stdc.stdio.stdin))) {
				migemo_d.rxgen.rxgen_add(prx, buf);
			}

			char* ans = migemo_d.rxgen.rxgen_generate(prx);

			scope (exit) {
				if (ans != null) {
					migemo_d.rxgen.rxgen_release(prx, ans);
					ans = null;
				}
			}

			core.stdc.stdio.printf("rxgen=%s\n", ans);
		}

		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "n_rnode_new=%d\n", migemo_d.rxgen.n_rnode_new);
		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "n_rnode_delete=%d\n", migemo_d.rxgen.n_rnode_delete);
	}

