// Copyright (c) 2020-2021 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module pref

import os

pub struct Preferences {
pub mut:
	debug            bool
	verbose          bool
pub:
	vroot            string
	vmodules_path    string
}

pub fn new_preferences() Preferences {
	p := Preferences{
		vroot: os.dir(vexe_path())
		vmodules_path: os.vmodules_dir()
	}
	return p
}

pub fn vexe_path() string {
	vexe := os.getenv('VEXE')
	if vexe != '' {
		return vexe
	}
	real_vexe_path := os.real_path(os.executable())
	os.setenv('VEXE', real_vexe_path, true)
	return real_vexe_path
}