#! /bin/sh

# Automake requires that ChangeLog exist.
touch ChangeLog

autoreconf -v --install || exit 1
#glib-gettextize --force --copy || exit 1
./configure --enable-maintainer-mode "$@"
