module pref

import os

pub struct Preferences {
pub mut:
	debug            bool
	verbose          bool
pub:
	vroot            string
}

pub fn new_preferences() Preferences {
	p := Preferences{
		vroot: os.dir(vexe_path())
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