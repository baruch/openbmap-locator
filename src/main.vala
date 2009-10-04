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

		private void init() {
			loc = new GSMLocation("cell.db");
			gypsy = new GypsyProvider(loc);

			try {
				var conn = DBus.Bus.get(DBus.BusType. SESSION);
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
