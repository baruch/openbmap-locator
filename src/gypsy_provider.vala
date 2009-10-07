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
	enum GypsyDeviceFixStatus {
		INVALID = 0,
		NONE,
		FIX_2D,
		FIX_3D
	}

	[DBus (name = "org.freedesktop.Gypsy.Server")]
	public interface GypsyServer {
		public abstract DBus.ObjectPath Create(string path) throws DBus.Error;
	}

	[DBus (name = "org.freedesktop.Gypsy.Device")]
	public interface GypsyDevice {
		public abstract bool GetConnectionStatus() throws DBus.Error;
		public abstract int GetFixStatus() throws DBus.Error;
		public abstract void Start() throws DBus.Error;
		public abstract void Stop() throws DBus.Error;

		public signal void ConnectionChanged(bool status);
		public signal void FixStatusChanged(int fix);
	}

	[DBus (name = "org.freedesktop.Gypsy.Course")]
	public interface GypsyCourse {
		public abstract void GetCourse(out int fields, out int timestamp, out double speed, out double direction, out double climb) throws DBus.Error;
		public signal void CourseChanged(int fields, int timestamp, double speed, double direction, double climb);
	}

	[DBus (name = "org.freedesktop.Gypsy.Accuracy")]
	public interface GypsyAccuracy {
		public abstract void GetAccuracy(out int fields, out double pdop, out double hdop, out double vdop) throws DBus.Error;
		public signal void AccuracyChanged(int fields, double pdop, double hdop, double vdop);
	}

	[DBus (name = "org.freedesktop.Gypsy.Position")]
	public interface GypsyPosition {
		public abstract void GetPosition(out int fields, out int timestamp, out double lat, out double lon, out double alt) throws DBus.Error;
		public signal void PositionChanged(int fields, int timestamp, double lat, double lon, double alt);
	}

	/*
	[DBus (name = "org.freedesktop.Gypsy.Satellite")]
	public interface GypsySatellite {
		public abstract PtrArray GetSatellites() throws DBus.Error;
		public signal void SatellitesChanged(PtrArray sats);
	}
	*/

	public class GypsyProvider : Object, GypsyServer, GypsyDevice, GypsyCourse, GypsyAccuracy, GypsyPosition {
		private GSMLocation loc;

		public GypsyProvider(GSMLocation loc) {
			this.loc = loc;
			this.loc.fix_changed += fix_changed;
			this.loc.position_changed += position_changed;
		}

		private void fix_changed() {
			// Update unimplemented signals with their default data
			ConnectionChanged(true);
			FixStatusChanged(GetFixStatus());

			int fields;
			try {
				double pdop;
				double hdop;
				double vdop;
				GetAccuracy(out fields, out pdop, out hdop, out vdop);
				AccuracyChanged(fields, pdop, hdop, vdop);
			} catch (DBus.Error e) {
				debug("error when getting accuracy: %s", e.message);
			}

			try {
				int timestamp;
				double speed;
				double direction;
				double climb;
				GetCourse(out fields, out timestamp, out speed, out direction, out climb);
				CourseChanged(fields, timestamp, speed, direction, climb);
			} catch (DBus.Error e) {
				debug("error when getting course: %s", e.message);
			}
		}

		private void position_changed() {
			int timestamp;
			double lat;
			double lon;
			double alt;
			int fields;
			try {
				GetPosition(out fields, out timestamp, out lat, out lon, out alt);
			} catch (DBus.Error e) {
				timestamp = 0;
				lat = 0.0;
				lon = 0.0;
				alt = 0.0;
				fields = 0;
			}
			PositionChanged(fields, timestamp, lat, lon, alt);
		}

		/* Server */
		public DBus.ObjectPath Create(string path) throws DBus.Error {
			return new DBus.ObjectPath("/org/openBmap/location/Gypsy");
		}

		/* Device */
		public bool GetConnectionStatus() { return loc.is_active(); }

		public int GetFixStatus() throws DBus.Error {
			if (!loc.is_active())
				return GypsyDeviceFixStatus.INVALID;

			if (loc.has_fix())
				return GypsyDeviceFixStatus.FIX_2D;
			else
				return GypsyDeviceFixStatus.NONE;
		}

		public void Start() throws DBus.Error {
			loc.start();
		}

		public void Stop() throws DBus.Error {
			loc.stop();
		}

		/* Course */
		public void GetCourse(out int fields, out int timestamp, out double speed, out double direction, out double climb) throws DBus.Error {
			fields = 0;
			timestamp = loc.timestamp;
			speed = 0.0;
			direction = 0.0;
			climb = 0.0;
		}

		/* Accuracy */
		public void GetAccuracy(out int fields, out double pdop, out double hdop, out double vdop) throws DBus.Error {
			double dop = 100.0;
			if (loc.has_fix()) {
				fields = 3;
				dop = 50.0;
			} else
				fields = 0;
			pdop = dop;
			hdop = dop;
			vdop = 100.0; // We have no altitude information
		}

		/* Position */
		public void GetPosition(out int fields, out int timestamp, out double lat, out double lon, out double alt) throws DBus.Error {
			if (loc.has_fix()) {
				fields = 3;
				timestamp = loc.timestamp;
				lat = loc.lat;
				lon = loc.lon;
				alt = 0.0;
			} else {
				fields = 0;
				timestamp = 0;
				lat = 0.0;
				lon = 0.0;
				alt = 0.0;
			}
		}
	}
}
