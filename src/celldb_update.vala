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
	public class CellDBUpdate : Object {
		private string dbname;
		private GSMLocation gsmloc;
		private unowned KeyFile conf;
		private time_t last_download;
		private bool in_download;
		private Soup.SessionAsync session;

		public signal void conf_needs_saving();

		public CellDBUpdate(string dbname, GSMLocation gsmloc, KeyFile conf) {
			this.dbname = dbname;
			this.gsmloc = gsmloc;
			this.conf = conf;
			this.last_download = 0;

			session = new Soup.SessionAsync();
			session.user_agent = "openbmap-locator";
			Timeout.add_seconds(3600, cb_timer);
			cb_timer(); // Try to download on startup
		}

		private bool cb_timer() {
			if (in_download)
				return true;

			time_t now = time_t();
			if (now < this.last_download + 7*24*60*60)
				return true;

			start_download();
			return true;
		}

		private void start_download() {
			if (in_download) {
				debug("cannot start download, already in download");
				return;
			}

			debug("Start download");
			Soup.Message msg = new Soup.Message("GET", "http://openbmap.ev-en.org/cell1.db");
			try {
				string last_modified = this.conf.get_string("download", "last_modified");
				if (last_modified != null && last_modified.len() > 0)
					msg.request_headers.append("If-Modified-Since", last_modified);
			} catch (KeyFileError e) {
				debug("Error when getting last modified entry from conf: %s", e.message);
			}
			this.session.queue_message(msg, cb_msg);
			in_download = true;
		}

		private void cb_msg(Soup.Session session, Soup.Message msg) {
			debug("session callback");
			debug("status %u", msg.status_code);
			if (msg.status_code == Soup.KnownStatusCode.OK)
				save_file(msg);
			else if (msg.status_code == Soup.KnownStatusCode.NOT_MODIFIED)
				this.last_download = time_t();
			in_download = false;
		}

		private void save_file(Soup.Message msg) {
			unowned Soup.Buffer buf = msg.response_body.flatten();

			string content_length = msg.response_headers.get("Content-Length");
			if (content_length != null && content_length.len() > 0) {
				int http_len = content_length.to_int();
				if (http_len != buf.length) {
					debug("Expected length (%s) and the buffer length (%llu) received do not match, download failed", content_length, buf.length);
					return;
				}
			}

			try {
				var f = File.new_for_path(this.dbname + ".tmp");
				var stream = f.create(0, null);
				size_t bytes_written;
				stream.write_all(buf.data, buf.length, out bytes_written, null);
				stream.close(null);
				if (bytes_written != buf.length) {
					debug("Error while writing to temp file");
					return;
				}

				this.gsmloc.closeDB();

				var target_f = File.new_for_path(this.dbname);
				f.move(target_f, FileCopyFlags.OVERWRITE, null, null);

				this.gsmloc.openDB();
				this.last_download = time_t();

				msg.response_headers.foreach((name, value) => { debug("key %s: %s", name, value); });

				string last_modified = msg.response_headers.get("Last-Modified");
				debug("Got last modified: %s", last_modified);
				if (last_modified != null && last_modified.len() > 0) {
					this.conf.set_string("download", "last_modified", last_modified);
					this.conf_needs_saving();
				}
			} catch (GLib.Error e) {
				debug("error saving file: %s", e.message);
			}
		}
	}
}
