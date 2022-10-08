// Copyright (c) 2020-2021 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module pref

import os

pub struct Preferences {
pub mut:
	debug            bool
	verbose          bool
	skip_builtin     bool
	skip_imports     bool
pub:
	vroot            string = os.dir(vexe_path())
	vmodules_path    string = os.vmodules_dir()
}

pub fn new_preferences() Preferences {
	return Preferences{}
}

pub fn new_preferences_using_options(options []string) Preferences {
	return Preferences{
		// config flags
		debug: '--debug' in options || '-d' in options
		verbose: '--verbose' in options || '-v' in options
		skip_builtin: '--skip-builtin' in options
		skip_imports: '--skip-imports' in options
	}
}

pub fn vexe_path() string {
	vexe := os.getenv('VEXE')
	if vexe != '' {
		return vexe
	}
	panic('VEXE not set. Set it manually, or use `v run file.v` for now')
	// TODO: uncomment once vlib is with tinyv
	// real_vexe_path := os.real_path(os.executable())
	// os.setenv('VEXE', real_vexe_path, true)
	// return real_vexe_path
}