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
		DataOutputStream log_stream;

		private GLib.File get_data_dir() throws GLib.Error {
			File f = File.new_for_path(Environment.get_home_dir());
			f = f.get_child(".openBmap");
			if (!f.query_exists(null)) {
				bool success = f.make_directory(null);
				if (!success)
					debug("Create directory %s result is %s", f.get_path(), success.to_string());
			}
			return f;
		}

		private GLib.File get_conf_file() throws GLib.Error {
			return get_data_dir().get_child("locator.conf");
		}

		private string get_celldb_filename() throws GLib.Error {
			return get_data_dir().get_child("cell.db").get_path();
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

		private void our_log_handler(string? log_domain, LogLevelFlags log_levels, string message) {
			if (this.log_stream == null)
				return;

			try {
				string t = Time.local(time_t()).to_string();
				this.log_stream.put_string(t, null);
				this.log_stream.put_string(" ", null);
				if (log_domain == null)
					log_domain = "UNKNOWN";
				this.log_stream.put_string(log_domain, null);
				this.log_stream.put_string(":", null);
				this.log_stream.put_string(message, null);
				this.log_stream.put_string("\n", null);
			} catch (GLib.Error e) {
				stderr.printf("Error writing to log file: %s", e.message);
			}
		}

		private void init_log() {
			try {
				var log_file_stream = File.new_for_path("/var/log/openbmap-locator.log").append_to(FileCreateFlags.NONE, null);
				this.log_stream = new DataOutputStream(log_file_stream);

				Log.set_default_handler(our_log_handler);
			} catch (GLib.Error e) {
				debug("Error creating log file: %s", e.message);
			}
		}

		private void init() {
			load_conf();

			string celldb_filename;
			try {
				celldb_filename = get_celldb_filename();
			} catch (GLib.Error e) {
				debug("Error while getting cell db file: %s", e.message);
				assert_not_reached();
			}
			loc = new GSMLocation(celldb_filename);
			loc.openDB();

			updater = new CellDBUpdate(celldb_filename, loc, conf);
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
			init_log();

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
