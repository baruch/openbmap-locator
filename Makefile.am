SUBDIRS = data src

dist-hook: gen-ChangeLog

gen_start_date = 2009-03-12
.PHONY: gen-ChangeLog
gen-ChangeLog:
	if test -d .git; then								\
	  $(top_srcdir)/gitlog-to-changelog					\
	    --since=$(gen_start_date) > $(distdir)/cl-t;	\
	  rm -f $(distdir)/ChangeLog;						\
	  mv $(distdir)/cl-t $(distdir)/ChangeLog;			\
	fi

EXTRA_DIST = \
	gitlog-to-changelog

MAINTAINERCLEANFILES = \
	Makefile.in Makefile aclocal.m4 config.guess \
	config.h.in config.sub configure install-sh \
	ltconfig ltmain.sh missing mkinstalldirs \
	stamp-h.in acconfig.h stamp-h depcomp
