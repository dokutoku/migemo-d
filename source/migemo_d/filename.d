/*
 * filename.c - Operate filename.
 *
 * Last change: 20-Sep-2009.
 * Written by:  Muraoka Taro  <koron@tka.att.ne.jp>
 */
module migemo_d.filename;


private static import core.stdc.string;

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

/**
 * Cut out base string of filename from filepath.  If base is null, then
 * return length that require for store base name.
 */
extern (C)
pure nothrow @nogc
public int filename_base(char* base, const (char)* path)

	in
	{
		assert(path != null);
	}

	do
	{
		int len = .my_strlen(path) - 1;
		int i;

		for (i = len; i >= 0; --i) {
			if (path[i] == '.') {
				break;
			}
		}

		int end;

		if (i <= 0) {
			end = len;
		} else {
			end = i - 1;
		}

		for (i = end; i >= 0; --i) {
			if ((path[i] == '\\') || (path[i] == '/')) {
				++i;

				break;
			}
		}

		if (i < 0) {
			++i;
		}

		len = end - i + 1;

		if (base != null) {
			core.stdc.string.strncpy(base, path + i, len);
			base[len] = '\0';
		}

		return len;
	}

/**
 * Cut out directroy string from filepath.  If dir is null, then return
 * length that require for store directory.
 */
extern (C)
pure nothrow @nogc
public int filename_directory(char* dir, const (char)* path)

	in
	{
		assert(path != null);
	}

	do
	{
		int i;

		for (i = .my_strlen(path) - 1; i >= 0; --i) {
			if ((path[i] == '\\') || (path[i] == '/')) {
				break;
			}
		}

		if (i <= 0) {
			if (dir != null) {
				dir[0] = '\0';
			}

			return 0;
		}

		if (dir != null) {
			core.stdc.string.strncpy(dir, path, i + 1);
			dir[i] = '\0';
		}

		return i;
	}

/**
 * Cut out extension of filename or filepath. If ext is null, then return
 * length that require for store extension.
 */
extern (C)
pure nothrow @nogc
public int filename_extension(char* ext, const (char)* path)

	in
	{
		assert(path != null);
	}

	do
	{
		int len = .my_strlen(path);
		int i;

		for (i = len - 1; i >= 0; --i) {
			if (path[i] == '.') {
				break;
			}
		}

		if ((i < 0) || (i == (len - 1))) {
			assert(ext != null);
			ext[0] = '\0';

			return 0;
		}

		len -= ++i;

		if (ext != null) {
			core.stdc.string.strcpy(ext, path + i);
		}

		return len;
	}

/**
 * Cut out filename string from filepath.  If name is null, then return
 * length that require for store directory.
 */
extern (C)
pure nothrow @nogc
public int filename_filename(char* name, const (char)* path)

	in
	{
		assert(path != null);
	}

	do
	{
		int len = .my_strlen(path);
		int i;

		for (i = len - 1; i >= 0; --i) {
			if ((path[i] == '\\') || (path[i] == '/')) {
				break;
			}
		}

		++i;
		len -= i;

		if (name != null) {
			core.stdc.string.strncpy(name, path + i, len);
			name[len] = '\0';
		}

		return len;
	}

/**
 * Generate file full path name.
 */
extern (C)
pure nothrow @nogc
public int filename_generate(char* filepath, const (char)* dir, const (char)* base, const (char)* ext)

	in
	{
	}

	do
	{
		if (filepath != null) {
			filepath[0] = '\0';
		}

		int len = 0;

		if (dir != null) {
			if (filepath != null) {
				core.stdc.string.strcat(filepath, dir);
				core.stdc.string.strcat(filepath, "/");
			}

			len += .my_strlen(dir) + 1;
		}

		if (base != null) {
			if (filepath != null) {
				core.stdc.string.strcat(filepath, base);
			}

			len += .my_strlen(base);
		}

		if (ext != null) {
			if (filepath != null) {
				core.stdc.string.strcat(filepath, ".");
				core.stdc.string.strcat(filepath, ext);
			}

			len += 1 + .my_strlen(ext);
		}

		return len;
	}
