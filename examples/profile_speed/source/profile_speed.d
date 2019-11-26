/*
 * profile_speed.c - スピード計測
 *
 * Written By:  MURAOKA Taro <koron@tka.att.ne.jp>
 * Last Change: 20-Jun-2004.
 */
module profile_speed.profile_speed;


private static import core.stdc.stdio;
private static import migemo_d.migemo;

enum NUM_TRIAL = 10;
enum DICTDIR = "../../dict";
enum DICT_FILE = DICTDIR ~ "/migemo-dict\0";

nothrow @nogc
int main()

	do
	{
		core.stdc.stdio.printf("Start\n");

		migemo_d.migemo.migemo* pmig = migemo_d.migemo.migemo_open(DICT_FILE.ptr);

		scope (exit) {
			if (pmig != null) {
				migemo_d.migemo.migemo_close(pmig);
				pmig = null;
			}
		}

		core.stdc.stdio.printf("Loaded\n");

		if (pmig != null) {
			char[2] key = '\0';

			for (size_t i = 0; i < NUM_TRIAL; ++i) {
				core.stdc.stdio.printf("[%zu] Progress... ", i);

				for (key[0] = 'a'; key[0] <= 'z'; ++key[0]) {
					core.stdc.stdio.printf("%s", &(key[0]));
					core.stdc.stdio.fflush(core.stdc.stdio.stdout);
					char* ans = migemo_d.migemo.migemo_query(pmig, &(key[0]));
					migemo_d.migemo.migemo_release(pmig, ans);
				}

				core.stdc.stdio.printf("\n");
			}
		}

		return 0;
	}
