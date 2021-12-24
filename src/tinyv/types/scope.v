// Copyright (c) 2020-2021 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module types

// TODO: this MIGHT be moved to anohter module, here for now

// pub type Object = Module | Type
pub type Object = Module | Primitive | Array | Enum | Map | Pointer | Struct

pub struct Scope{
	parent  &Scope
mut:
	objects map[string]Object
	start   int
	end     int
}

pub fn new_scope(parent &Scope) &Scope {
	unsafe { return &Scope{
		parent: parent
	} }
}

pub fn (mut s Scope) register(name string, obj Object) {
	s.objects[name] = obj
}
