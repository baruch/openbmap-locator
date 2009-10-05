/*
 *  Copyright (C) 2009
 *      Authors (alphabetical) :
 *              Baruch Even <baruch@ev-en.org>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU Public License as published by
 *  the Free Software Foundation; version 2 of the license.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser Public License for more details.
 */
using GLib;

namespace openBmap {
	
	class Deamon {
		GSMLocation loc;
		GypsyProvider gypsy;
		CellDBUpdate updater;
		KeyFile conf;
		bool conf_needs_saving;

		private GLib.File get_conf_file() throws GLib.Error {
			File f = File.new_for_path(Environment.get_home_dir());
			f = f.get_child(".openBmap");
			if (!f.query_exists(null)) {
				bool success = f.make_directory(null);
				if (!success)
					debug("Create directory %s result is %s", f.get_path(), success.to_string());
			}
			return f.get_child("locator.conf");
		}

		private void load_conf() {
			conf = new KeyFile();
			try {
				var f = get_conf_file();
				conf.load_from_file(f.get_path(), KeyFileFlags.KEEP_COMMENTS);
				conf_needs_saving = false;
			} catch (KeyFileError e) {
				debug("Key file error %s", e.message);
			} catch (FileError e) {
				debug("File Error %s", e.message);
			} catch (GLib.Error e) {
				debug("GLib Error %s", e.message);
			}
		}

		private bool save_conf() {
			try {
				debug("Saving conf");
				var f = get_conf_file();
				size_t len;
				GLib.Error e;
				string data = this.conf.to_data(out len, out e);
				if (e != null) {
					debug("Error converting conf to string: %s", e.message);
				} else {
					f.replace_contents(data, len, null, false, FileCreateFlags.NONE, null, null);
				}
			} catch (GLib.Error e) {
				debug("Error while saving conf: %s", e.message);
			}
			conf_needs_saving = false;
			return false;
		}

		private void delayed_save_conf() {
			debug("Delayed saving requested");
			if (conf_needs_saving)
				return; // We will do it shortly anyway

			debug("Delayed saving initiated");
			Timeout.add_seconds(1, save_conf);
		}

		private void init() {
			load_conf();

			loc = new GSMLocation("cell.db");
			loc.openDB();

			updater = new CellDBUpdate("cell.db", loc, conf);
			updater.conf_needs_saving += delayed_save_conf;

			gypsy = new GypsyProvider(loc);

			try {
				var conn = DBus.Bus.get(DBus.BusType.SYSTEM);
				dynamic DBus.Object bus = conn.get_object(
						"org.freedesktop.DBus",
						"/org/freedesktop/DBus",
						"org.freedesktop.DBus");

				// try to register service in session bus
				uint request_name_result = bus.request_name("org.openBmap.location", (uint) 0);

				if (request_name_result == DBus.RequestNameReply.PRIMARY_OWNER) {
					// start new dbus server
					conn.register_object ("/org/openBmap/location/Gypsy", gypsy);
				} else {
					// TODO, it's already running or other failure. HANDLE ME
					error("Server already running or other failure");
				}
			} catch (DBus.Error e) {
				debug("Oops: %s\n", e.message);
			}
		}

		private void uninit() {
		}

		public void run(string[] args) {
			message("Starting openbmap-locator");
			var loop = new MainLoop(null, false);
			init();
			message("Started openbmap-locator");
			
			/* Run main loop */
			loop.run();
			
			message("Stoping openbmap-locator");
			uninit();
			message("Stoped openbmap-locator");
		}
		
		public static void main(string[] args) {
			Deamon deamon = new Deamon();
			deamon.run(args);
		}
	}
}
