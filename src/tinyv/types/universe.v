// Copyright (c) 2020-2023 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
// [has_globals]
module types

// __global universe = init_universe()
const universe = init_universe()

const(
	bool_ = Primitive{props: .boolean}
	i8_   = Primitive{props: .integer, size: 8}
	i16_  = Primitive{props: .integer, size: 16}
	// i32_ = Primitive{props: .integer, size: 32}
	int_  = Primitive{props: .integer, size: 32}
	i64_  = Primitive{props: .integer, size: 64}
	u8_   = Primitive{props: .integer | .unsigned, size: 8}
	// byte_ = Primitive{props: .integer | .unsigned, size: 8}
	// byte_ = Alias{parent_type: u8_}
	u16_  = Primitive{props: .integer | .unsigned, size: 16}
	u32_  = Primitive{props: .integer | .unsigned, size: 32}
	u64_  = Primitive{props: .integer | .unsigned, size: 64}
	f16_  = Primitive{props: .float, size: 16}
	f32_  = Primitive{props: .float, size: 32}
)

pub fn init_universe() &Scope {
	// universe scope
	mut universe_ := new_scope(unsafe{nil})
	universe_.register('bool', bool_)
	universe_.register('i8', i8_)
	universe_.register('i16', i16_)
	// universe_.register('i32', i32_)
	universe_.register('int', int_)
	universe_.register('i64', i64_)
	universe_.register('u8', u8_)
	// universe_.register('byte', byte_)
	universe_.register('u16', u16_)
	universe_.register('u64', u64_)
	universe_.register('f16', f16_)
	universe_.register('f32', f32_)
	return universe_
}
