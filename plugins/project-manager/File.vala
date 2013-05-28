// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2013 Julien Spautz <spautz.julien@gmail.com>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses/>

  END LICENSE
***/

namespace ProjectManager {
    /**
     * Class for easily dealing with files.
     */
    internal class File : GLib.Object {

        public GLib.File file;

        private enum Type {
            VALID_FILE,
            VALID_FOLDER,
            UNKNOWN,
            INVALID
        }

        public File (string path) {
            file = GLib.File.new_for_path (path);
            if (!exists) {
                critical (@"File '$path' does not exist");
            }
        }

        // returns the path the file
        string _path = null;
        public string path {
            get { return _path != null ? _path : _path = file.get_path (); }
        }

        // returns the basename of the file
        string _name = null;
        public string name {
            get { return _name != null ? _name : _name = file.get_basename (); }
        }

        // returns the icon of the file's content type
        GLib.Icon _icon = null;
        public GLib.Icon icon {
            get {
                if (_icon != null)
                    return _icon;
                var info = new FileInfo ();
                try {
                    info = file.query_info ("standard::*", 0);
                } catch (GLib.Error error) {
                    warning (error.message);
                    return (GLib.Icon) null;
                }
                return _icon = GLib.ContentType.get_icon (info.get_content_type ());
            }
        }

        // checks if file exists
        public bool exists {
            get { return file.query_exists (); }
        }

        Type _type = Type.UNKNOWN;
        // checks if we're dealing with a non-hidden, non-backup directory
        public bool is_valid_directory {
            get {
                if (_type == Type.VALID_FILE)
                    return false;
                if (_type == Type.VALID_FOLDER)
                    return true;
                if (_type == Type.INVALID)
                    return false;
                    
                var info = new FileInfo ();
                try {
                    info = file.query_info ("standard::*", 0);
                } catch (GLib.Error error) {
                    warning (error.message);
                    _type = Type.INVALID;
                    return false;
                }

                if (file.query_file_type (FileQueryInfoFlags.NONE) != FileType.DIRECTORY ||
                    info.get_is_hidden () || info.get_is_backup ()) {
                    return false;
                }
                
                bool has_valid_children = false;
                foreach (var child in children) {
                    if (child.is_valid_textfile) {
                        _type = Type.VALID_FOLDER;
                        return has_valid_children = true;
                    }
                }
                
                foreach (var child in children) {
                    if (child.is_valid_directory) {
                        has_valid_children = true;
                        _type = Type.VALID_FOLDER;
                    return has_valid_children = true;
                    }
                }

                return false;
            }
        }

        // checks if we're dealing with a textfile
        public bool is_valid_textfile {
            get {
                if (_type == Type.VALID_FILE)
                    return true;
                if (_type == Type.VALID_FOLDER)
                    return false;
                if (_type == Type.INVALID)
                    return false;
                    
                var info = new FileInfo ();
                try {
                    info = file.query_info ("standard::*", 0);
                } catch (GLib.Error error) {
                    warning (error.message);
                    _type = Type.INVALID;
                    return false;
                }
                if (file.query_file_type (FileQueryInfoFlags.NONE) == FileType.REGULAR &&
                    ContentType.is_a (info.get_content_type (), "text/*") &&
                    !info.get_is_backup () &&
                    !info.get_is_hidden ()) {
                    _type = Type.VALID_FILE;
                    return true;
                }
                return false;
            }
        }

        // returns a list of all children of a directory
        GLib.List <File> _children = null;
        public GLib.List <File> children {
            get {
                if (_children != null)
                    return _children;

                var parent = GLib.File.new_for_path (file.get_path ());
                try {
                    var enumerator = parent.enumerate_children ("standard::*", 0);

                    var file_info = new FileInfo ();
                    while ((file_info = enumerator.next_file ()) != null) {
                        var child = parent.get_child (file_info.get_name ());
                        _children.append (new File (child.get_path ()));
                    }
                } catch (GLib.Error error) {
                    warning (error.message);
                }

                return _children;
            }
        }

        public void reset_cache () {
            _name = null;
            _path = null;
            _icon = null;
            _children = null;
            _type = Type.UNKNOWN;
        }
        
        public static int compare (File a, File b) {
            if (a.is_valid_directory && b.is_valid_textfile)
                return -1;
            if (a.is_valid_textfile && b.is_valid_directory)
                return 1;
            return strcmp (a.path.collate_key_for_filename (),
                           b.path.collate_key_for_filename ());
        }
    }
}
