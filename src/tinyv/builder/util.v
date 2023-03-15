// Copyright (c) 2020-2023 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module builder

import os

fn (b &Builder) get_vlib_module_path(mod string) string {
	mod_path := mod.replace('.', os.path_separator)
	return os.join_path(b.pref.vroot, 'vlib', mod_path)
}

// check for relative and then vlib
fn (b &Builder) get_module_path(mod string, importing_file_path string) string {
	mod_path := mod.replace('.', os.path_separator)
	// TODO: is this the best order?
	// vlib
	vlib_path := os.join_path(b.pref.vroot, 'vlib', mod_path)
	if os.is_dir(vlib_path) {
		return vlib_path
	}
	// ~/.vmodules
	vmodules_path := os.join_path(b.pref.vmodules_path, mod_path)
	if os.is_dir(vmodules_path) {
		return vmodules_path
	}
	// relative to file importing it
	relative_path := os.join_path(os.dir(importing_file_path), mod_path)
	if os.is_dir(relative_path) {
		return relative_path
	}
	panic('get_module_path: cannot find module path for $mod')
}

fn get_v_files_from_dir(dir string) []string {
	mod_files := os.ls(dir)  or {
		panic('error getting ls from $dir')
	}
	mut v_files := []string{}
	for file in mod_files {
		if !file.ends_with('.v') || file.ends_with('.js.v') || file.ends_with('_test.v') {
			continue
		}
		v_files << os.join_path(dir, file)
	}
	return v_files
}