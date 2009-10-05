AM_CFLAGS = \
	$(ALL_CFLAGS) \
	-include $(CONFIG_HEADER)

VALAFLAGS = \
	--thread \
	--vapidir vapi \
	--pkg dbus-glib-1 \
	--pkg sqlite3 \
	--pkg libsoup-2.4

bin_PROGRAMS = openbmap-locator

openbmap_locator_SOURCES = \
	main.vala \
	gypsy_provider.vala \
	gsm_location.vala \
	celldb_update.vala

openbmap_locator_LDADD = $(ALL_LIBS)
