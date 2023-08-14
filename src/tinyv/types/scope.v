// Copyright (c) 2020-2023 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module types

import tinyv.token

pub type Object = Const | Fn | Global | Module | Type | SmartCastSelector
// pub type Object = Const | Fn | Global | Module |
// 	Alias | Array | Enum | Map | Pointer | Primitive | String | Struct | SumType


struct SmartCastSelector {
	origin    Type
	field     string
	cast_type Type
}

pub struct Scope{
	parent  &Scope = unsafe { nil }
mut:
	objects map[string]Object
	// smartcasts map[string]Type
	// TODO: it may be more efficient looking up local vars using an ID
	// even if we had to store them in two different places. investigate.
	// variables []Object
	start   int
	end     int
}

pub fn new_scope(parent &Scope) &Scope {
	unsafe { return &Scope{
		parent: parent
	} }
}

pub fn (mut s Scope) lookup(name string) ?Object {
	if obj := s.objects[name] {
		return obj
	}
	return none
}

pub fn (mut s Scope) lookup_parent(name string, pos token.Pos) ?Object {
	mut scope := unsafe { s }
	for ; scope != unsafe { nil }; scope = scope.parent {
		if obj := scope.lookup(name) {
			return obj
			// if !pos.is_valid() || cmpPos(obj.scopePos(), pos) <= 0 {
			// 	return s, obj
			// }
		}
	}
	// println('lookup_parent: NOT FOUND: $name')
	return none
}

pub fn (mut s Scope) lookup_parent_with_scope(name string, pos token.Pos) ?(&Scope, Object) {
	mut scope := unsafe { s }
	for ; scope != unsafe { nil }; scope = scope.parent {
		if obj := scope.lookup(name) {
			return scope, obj
			// if !pos.is_valid() || cmpPos(obj.scopePos(), pos) <= 0 {
			// 	return s, obj
			// }
		}
	}
	// println('lookup_parent: NOT FOUND: $name')
	return none
}

pub fn (mut s Scope) insert(name string, obj Object) {
	// println(' - register: $name: ${obj.type_name()}')
	// TODO/FIXME:
	// if name in s.objects {
	// 	println(' #### EXISTS: $name')
	// 	mut existing := s.objects[name] or { panic('should exist') }
	// 	if mut existing is Type {
	// 		if mut existing is Struct {
	// 			// if existing.name == 'mapnode' {
	// 				if obj is Type {
	// 					if obj is Struct {
	// 						existing.fields = obj.fields
	// 						// existing.fields << obj.fields
	// 					}
	// 				}
	// 			// }
	// 		}
	// 	}
	// 	// if name == 'mapnode' {
	// 	// 	println(obj)
	// 	// 	println(s.objects[name])
	// 	// 	panic('...')
	// 	// }
	// }
	if name !in s.objects {
		s.objects[name] = obj
	}
}

pub fn (s &Scope) print(recurse_parents bool) {
	println('# SCOPE:')
	for name, obj in s.objects {
		println(' * ${name}: ${obj.type_name()}')
		// if obj is Type {
		// 	println('    - ${name}: ${obj.type_name()}')
		// }
	}
	if recurse_parents && s.parent != unsafe { nil } {
		s.parent.print(recurse_parents)
	}
}

pub fn (obj &Object) typ() Type {
	match obj {
		Const {
			return obj.typ
		}
		Fn {
			return obj.typ
		}
		Global {
			return obj.typ
		}
		Module {
			// TODO:
			println('#### got Module')
			return Type(u16_)
		}
		SmartCastSelector {
			return obj.origin
		}
		Type {
			return obj
		}
		// else {
		// 	panic('missing obj.typ() for ${obj.type_name()}')
		// }
	}
}