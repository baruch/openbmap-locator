AC_INIT(openbmap-locator, 0.1, http://www.openbmap.org/)
AC_PREREQ(2.52)
AC_CONFIG_SRCDIR(configure.ac)
AC_ISC_POSIX

AM_INIT_AUTOMAKE(1.6 dist-bzip2)
AM_CONFIG_HEADER(config.h)

AM_PROG_VALAC([0.7.0])
AM_SILENT_RULES
AM_MAINTAINER_MODE([enable])
AC_PROG_CC
AC_HEADER_STDC

PKG_CHECK_MODULES(ALL, dbus-glib-1 >= 0.70 dbus-1 >= 0.70 gthread-2.0 sqlite3)
AC_SUBST(ALL_CFLAGS)
AC_SUBST(ALL_LIBS)

AC_OUTPUT([
Makefile
src/Makefile
data/Makefile
])
