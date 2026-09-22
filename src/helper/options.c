// SPDX-License-Identifier: GPL-2.0-or-later

/***************************************************************************
 *   Copyright (C) 2004, 2005 by Dominic Rath                              *
 *   Dominic.Rath@gmx.de                                                   *
 *                                                                         *
 *   Copyright (C) 2007-2010 Øyvind Harboe                                 *
 *   oyvind.harboe@zylin.com                                               *
 ***************************************************************************/

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "configuration.h"
#include "log.h"
#include "command.h"

#include <getopt.h>

#include <limits.h>
#include <stdlib.h>
#include <string.h>
#if IS_DARWIN
#include <libproc.h>
#endif
/* sys/sysctl.h is deprecated on Linux from glibc 2.30 */
#ifndef __linux__
#ifdef HAVE_SYS_SYSCTL_H
#include <sys/sysctl.h>
#endif
#endif
#if IS_WIN32 && !IS_CYGWIN
#include <windows.h>
#endif

static int help_flag, version_flag;

static const struct option long_options[] = {
	{"help",		no_argument,			&help_flag,		1},
	{"version",		no_argument,			&version_flag,	1},
	{"debug",		optional_argument,		NULL,			'd'},
	{"file",		required_argument,		NULL,			'f'},
	{"search",		required_argument,		NULL,			's'},
	{"log_output",	required_argument,		NULL,			'l'},
	{"command",		required_argument,		NULL,			'c'},
	{NULL, 0, NULL, 0}
};

int configuration_output_handler(struct command_context *context, const char *line)
{
	LOG_USER_N("%s", line);

	return ERROR_OK;
}

/* Return the canonical path to the directory the openocd executable is in.
 * The path should be absolute, use / as path separator and have all symlinks
 * resolved. The returned string is malloc'd. */
static char *find_exe_path(void)
{
	char *exepath = NULL;

	do {
#if IS_WIN32 && !IS_CYGWIN
		exepath = malloc(MAX_PATH);
		if (!exepath)
			break;
		GetModuleFileName(NULL, exepath, MAX_PATH);

		/* Convert path separators to UNIX style, should work on Windows also. */
		for (char *p = exepath; *p; p++) {
			if (*p == '\\')
				*p = '/';
		}

#elif IS_DARWIN
		exepath = malloc(PROC_PIDPATHINFO_MAXSIZE);
		if (!exepath)
			break;
		if (proc_pidpath(getpid(), exepath, PROC_PIDPATHINFO_MAXSIZE) <= 0) {
			free(exepath);
			exepath = NULL;
		}

#elif defined(CTL_KERN) && defined(KERN_PROC) && defined(KERN_PROC_PATHNAME) /* *BSD */
#ifndef PATH_MAX
#define PATH_MAX 1024
#endif
		char *path = malloc(PATH_MAX);
		if (!path)
			break;
		int mib[] = { CTL_KERN, KERN_PROC, KERN_PROC_PATHNAME, -1 };
		size_t size = PATH_MAX;

		if (sysctl(mib, (u_int)ARRAY_SIZE(mib), path, &size, NULL, 0) != 0)
			break;

#ifdef HAVE_REALPATH
		exepath = realpath(path, NULL);
		free(path);
#else
		exepath = path;
#endif

#elif defined(HAVE_REALPATH) /* Assume POSIX.1-2008 */
		/* Try Unices in order of likelihood. */
		exepath = realpath("/proc/self/exe", NULL); /* Linux/Cygwin */
		if (!exepath)
			exepath = realpath("/proc/self/path/a.out", NULL); /* Solaris */
		if (!exepath)
			exepath = realpath("/proc/curproc/file", NULL); /* FreeBSD (Should be covered above) */
#endif
	} while (0);

	if (exepath) {
		/* Strip executable file name, leaving path */
		*strrchr(exepath, '/') = '\0';
	} else {
		LOG_WARNING("Could not determine executable path, using configured BINDIR.");
		LOG_DEBUG("BINDIR = %s", BINDIR);
#ifdef HAVE_REALPATH
		exepath = realpath(BINDIR, NULL);
#else
		exepath = strdup(BINDIR);
#endif
	}

	return exepath;
}

static char *find_relative_path(const char *from, const char *to)
{
	size_t i;

	/* Skip common /-separated parts of from and to */
	i = 0;
	for (size_t n = 0; from[n] == to[n]; n++) {
		if (from[n] == '\0') {
			i = n;
			break;
		}
		if (from[n] == '/')
			i = n + 1;
	}
	from += i;
	to += i;

	/* Count number of /-separated non-empty parts of from */
	i = 0;
	while (from[0] != '\0') {
		if (from[0] != '/')
			i++;
		const char *next = strchr(from, '/');
		if (!next)
			break;
		from = next + 1;
	}

	/* Prepend that number of ../ in front of to */
	char *relpath = malloc(i * 3 + strlen(to) + 1);
	relpath[0] = '\0';
	for (size_t n = 0; n < i; n++)
		strcat(relpath, "../");
	strcat(relpath, to);

	return relpath;
}

static void add_user_dirs(void)
{
	char *path;

#if IS_WIN32
	const char *appdata = getenv("APPDATA");

	if (appdata) {
		path = alloc_printf("%s/OpenOCD", appdata);
		if (path) {
			/* Convert path separators to UNIX style, should work on Windows also. */
			for (char *p = path; *p; p++) {
				if (*p == '\\')
					*p = '/';
			}
			add_script_search_dir(path);
			free(path);
		}
	}
	/* WIN32 may also have HOME defined, particularly under Cygwin, so add those paths below too */
#endif

	const char *home = getenv("HOME");
#if IS_DARWIN
	if (home) {
		path = alloc_printf("%s/Library/Preferences/org.openocd", home);
		if (path) {
			add_script_search_dir(path);
			free(path);
		}
	}
#endif
	const char *xdg_config = getenv("XDG_CONFIG_HOME");

	if (xdg_config) {
		path = alloc_printf("%s/openocd", xdg_config);
		if (path) {
			add_script_search_dir(path);
			free(path);
		}
	} else if (home) {
		path = alloc_printf("%s/.config/openocd", home);
		if (path) {
			add_script_search_dir(path);
			free(path);
		}
	}

	if (home) {
		path = alloc_printf("%s/.openocd", home);
		if (path) {
			add_script_search_dir(path);
			free(path);
		}
	}
}

static void add_default_dirs(void)
{
	char *path;
	char *exepath = find_exe_path();
	char *bin2data = find_relative_path(BINDIR, PKGDATADIR);

	LOG_DEBUG("bindir=%s", BINDIR);
	LOG_DEBUG("pkgdatadir=%s", PKGDATADIR);
	LOG_DEBUG("exepath=%s", exepath);
	LOG_DEBUG("bin2data=%s", bin2data);

	/*
	 * The directory containing OpenOCD-supplied scripts should be
	 * listed last in the built-in search order, so the user can
	 * override these scripts with site-specific customizations.
	 */
	path = getenv("OPENOCD_SCRIPTS");
	if (path)
		add_script_search_dir(path);

	add_user_dirs();

	path = alloc_printf("%s/%s/%s", exepath, bin2data, "site");
	if (path) {
		add_script_search_dir(path);
		free(path);
	}

	path = alloc_printf("%s/%s/%s", exepath, bin2data, "scripts");
	if (path) {
		add_script_search_dir(path);
		free(path);
	}

	free(exepath);
	free(bin2data);
}

int parse_cmdline_args(struct command_context *cmd_ctx, int argc, char *argv[])
{
	int jtag_clock_khz = 200;   /* Default 200 kHz */
	int gdb_tcp_port = 3333;    /* Default GDB port 3333 */
	int telnet_tcp_port = 0; /* Default disabled */
	int tcl_tcp_port = 0;    /* Default disabled */

	for (int i = 1; i < argc; i++) {
		const char *arg = argv[i];

		if (strcmp(arg, "-h") == 0 || strcmp(arg, "--help") == 0) {
			LOG_OUTPUT("Open On-Chip Debugger (ARM968E-S CMSIS-DAP Dedicated Build)\n");
			LOG_OUTPUT("Usage: %s [options]\n\n", argv[0]);
			LOG_OUTPUT("Options:\n");
			LOG_OUTPUT("  -s, --speed <khz>        JTAG clock rate in kHz (default: 200)\n");
			LOG_OUTPUT("  -p, --port <port>        GDB server TCP port (default: 3333)\n");
			LOG_OUTPUT("      --gdb-port <port>    GDB server TCP port (default: 3333)\n");
			LOG_OUTPUT("      --telnet-port <port> Telnet console TCP port (default: 4444)\n");
			LOG_OUTPUT("      --tcl-port <port>    TCL RPC TCP port (default: 6666)\n");
			LOG_OUTPUT("  -h, --help               Display this help message\n");
			LOG_OUTPUT("  -v, --version            Display OpenOCD version\n");
			exit(0);
		} else if (strcmp(arg, "-v") == 0 || strcmp(arg, "--version") == 0) {
			/* Version string is printed on startup */
			exit(0);
		} else if (strcmp(arg, "-s") == 0 || strcmp(arg, "--speed") == 0) {
			if (i + 1 >= argc) {
				LOG_OUTPUT("Error: '%s' requires a clock rate in kHz (e.g. 200).\n", arg);
				return ERROR_FAIL;
			}
			i++;
			char *endptr = NULL;
			long val = strtol(argv[i], &endptr, 10);
			if (!endptr || *endptr != '\0' || val <= 0) {
				LOG_OUTPUT("Error: Invalid JTAG clock rate '%s'. Must be a positive integer in kHz.\n", argv[i]);
				return ERROR_FAIL;
			}
			jtag_clock_khz = (int)val;
		} else if (arg[0] == '-' && arg[1] == 's' && arg[2] != '\0') {
			/* e.g. -s500 */
			char *endptr = NULL;
			long val = strtol(arg + 2, &endptr, 10);
			if (!endptr || *endptr != '\0' || val <= 0) {
				LOG_OUTPUT("Error: Invalid JTAG clock rate '%s'. Must be a positive integer in kHz.\n", arg);
				return ERROR_FAIL;
			}
			jtag_clock_khz = (int)val;
		} else if (strcmp(arg, "-p") == 0 || strcmp(arg, "--port") == 0 || strcmp(arg, "--gdb-port") == 0) {
			if (i + 1 >= argc) {
				LOG_OUTPUT("Error: '%s' requires a TCP port number (e.g. 3333).\n", arg);
				return ERROR_FAIL;
			}
			i++;
			char *endptr = NULL;
			long val = strtol(argv[i], &endptr, 10);
			if (!endptr || *endptr != '\0' || val < 0 || val > 65535) {
				LOG_OUTPUT("Error: Invalid TCP port '%s'. Must be between 0 and 65535.\n", argv[i]);
				return ERROR_FAIL;
			}
			gdb_tcp_port = (int)val;
		} else if (arg[0] == '-' && arg[1] == 'p' && arg[2] != '\0') {
			/* e.g. -p3333 */
			char *endptr = NULL;
			long val = strtol(arg + 2, &endptr, 10);
			if (!endptr || *endptr != '\0' || val < 0 || val > 65535) {
				LOG_OUTPUT("Error: Invalid TCP port '%s'. Must be between 0 and 65535.\n", arg);
				return ERROR_FAIL;
			}
			gdb_tcp_port = (int)val;
		} else if (strcmp(arg, "--telnet-port") == 0) {
			if (i + 1 >= argc) {
				LOG_OUTPUT("Error: '--telnet-port' requires a port number (e.g. 4444).\n");
				return ERROR_FAIL;
			}
			i++;
			char *endptr = NULL;
			long val = strtol(argv[i], &endptr, 10);
			if (!endptr || *endptr != '\0' || val < 0 || val > 65535) {
				LOG_OUTPUT("Error: Invalid Telnet port '%s'. Must be between 0 and 65535.\n", argv[i]);
				return ERROR_FAIL;
			}
			telnet_tcp_port = (int)val;
		} else if (strcmp(arg, "--tcl-port") == 0) {
			if (i + 1 >= argc) {
				LOG_OUTPUT("Error: '--tcl-port' requires a port number (e.g. 6666).\n");
				return ERROR_FAIL;
			}
			i++;
			char *endptr = NULL;
			long val = strtol(argv[i], &endptr, 10);
			if (!endptr || *endptr != '\0' || val < 0 || val > 65535) {
				LOG_OUTPUT("Error: Invalid TCL port '%s'. Must be between 0 and 65535.\n", argv[i]);
				return ERROR_FAIL;
			}
			tcl_tcp_port = (int)val;
		} else if (arg[0] != '-') {
			/* Positional clock rate: e.g. openocd.exe 500 */
			char *endptr = NULL;
			long val = strtol(arg, &endptr, 10);
			if (!endptr || *endptr != '\0' || val <= 0) {
				LOG_OUTPUT("Error: Invalid JTAG clock rate '%s'. Must be a positive integer in kHz.\n", arg);
				LOG_OUTPUT("Usage: %s [-s <clock_khz>] [-p <tcp_port>]\n", argv[0]);
				return ERROR_FAIL;
			}
			jtag_clock_khz = (int)val;
		} else {
			LOG_OUTPUT("Error: Unrecognized option '%s'.\n", arg);
			LOG_OUTPUT("Usage: %s [-s <clock_khz>] [-p <tcp_port>]\n", argv[0]);
			return ERROR_FAIL;
		}
	}

	LOG_INFO("ARM968E-S CMSIS-DAP debugger: JTAG clock %d kHz, GDB TCP port %d",
		jtag_clock_khz, gdb_tcp_port);

	/* Set TCP ports */
	char *port_cmd = alloc_printf("gdb port %d", gdb_tcp_port);
	add_config_command(port_cmd);
	free(port_cmd);

	if (telnet_tcp_port > 0)
		port_cmd = alloc_printf("telnet port %d", telnet_tcp_port);
	else
		port_cmd = alloc_printf("telnet port disabled");
	add_config_command(port_cmd);
	free(port_cmd);

	if (tcl_tcp_port > 0)
		port_cmd = alloc_printf("tcl port %d", tcl_tcp_port);
	else
		port_cmd = alloc_printf("tcl port disabled");
	add_config_command(port_cmd);
	free(port_cmd);

	/* Fixed configuration for ARM968E-S via CMSIS-DAP in JTAG mode */
	add_config_command("adapter driver cmsis-dap");
	add_config_command("transport select jtag");

	char *speed_cmd = alloc_printf("adapter speed %d", jtag_clock_khz);
	add_config_command(speed_cmd);
	free(speed_cmd);

	add_config_command("jtag newtap arm968 cpu -irlen 4 -ircapture 0x1 -irmask 0x0f");
	add_config_command("target create arm968.cpu arm966e -endian little -tap arm968.cpu");
	add_config_command("reset_config none");

	add_default_dirs();

	return ERROR_OK;
}
