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

	[DBus (name = "org.freedesktop.Gypsy.Device")]
	public interface GypsyDevice {
		public abstract bool GetConnectionStatus() throws DBus.Error;
		public abstract int GetFixStatus() throws DBus.Error;
		public abstract bool Start() throws DBus.Error;
		public abstract bool Stop() throws DBus.Error;

		public signal void ConnectionChanged(bool status);
		public signal void FixStatusChanged(int fix);
	}

	[DBus (name = "org.freedesktop.Gypsy.Course")]
	public interface GypsyCourse {
		public abstract int GetCourse(out int timestamp, out double speed, out double direction, out double climb) throws DBus.Error;
		public signal void CourseChanged(int fields, int timestamp, double speed, double direction, double climb);
	}

	[DBus (name = "org.freedesktop.Gypsy.Accuracy")]
	public interface GypsyAccuracy {
		public abstract int GetAccuracy(out double pdop, out double hdop, out double vdop) throws DBus.Error;
		public signal void AccuracyChanged(int fields, double pdop, double hdop, double vdop);
	}

	[DBus (name = "org.freedesktop.Gypsy.Position")]
	public interface GypsyPosition {
		public abstract int GetPosition(out int timestamp, out double lat, out double lon, out double alt) throws DBus.Error;
		public signal void PositionChanged(int fields, int timestamp, double lat, double lon, double alt);
	}

	/*
	[DBus (name = "org.freedesktop.Gypsy.Satellite")]
	public interface GypsySatellite {
		public abstract PtrArray GetSatellites() throws DBus.Error;
		public signal void SatellitesChanged(PtrArray sats);
	}
	*/

	public class GypsyProvider : Object, GypsyDevice, GypsyCourse, GypsyAccuracy, GypsyPosition {
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

			double pdop;
			double hdop;
			double vdop;
			fields = GetAccuracy(out pdop, out hdop, out vdop);
			AccuracyChanged(fields, pdop, hdop, vdop);

			int timestamp;
			double speed;
			double direction;
			double climb;
			fields = GetCourse(out timestamp, out speed, out direction, out climb);
			CourseChanged(fields, timestamp, speed, direction, climb);
		}

		private void position_changed() {
			int timestamp;
			double lat;
			double lon;
			double alt;
			int fields;
			try {
				fields = GetPosition(out timestamp, out lat, out lon, out alt);
			} catch (DBus.Error e) {
				timestamp = 0;
				lat = 0.0;
				lon = 0.0;
				alt = 0.0;
				fields = 0;
			}
			PositionChanged(fields, timestamp, lat, lon, alt);
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

		public bool Start() throws DBus.Error {
			return loc.start();
		}

		public bool Stop() throws DBus.Error {
			return loc.stop();
		}

		/* Course */
		public int GetCourse(out int timestamp, out double speed, out double direction, out double climb) throws DBus.Error {
			timestamp = loc.timestamp;
			speed = 0.0;
			direction = 0.0;
			climb = 0.0;
			return 0;
		}

		/* Accuracy */
		public int GetAccuracy(out double pdop, out double hdop, out double vdop) throws DBus.Error {
			double dop = 100.0;
			if (loc.has_fix())
				dop = 50.0;
			pdop = dop;
			hdop = dop;
			vdop = 100.0; // We have no altitude information
			return 3; // pdop and hdop valid
		}

		/* Position */
		public int GetPosition(out int timestamp, out double lat, out double lon, out double alt) throws DBus.Error {
			if (loc.has_fix()) {
				timestamp = loc.timestamp;
				lat = loc.lat;
				lon = loc.lon;
				alt = 0.0;
				return 3;
			} else {
				timestamp = 0;
				lat = 0.0;
				lon = 0.0;
				alt = 0.0;
				return 0;
			}
		}
	}
}
