// Copyright (c) 2020-2023 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
// [has_globals]
module types

// __global universe = &Scope{parent: 0}

const(
	// TODO: v: allow initialising flags like so: `.integer | .unsigned`
	// seems as though support for this was added :)
	bool_ = Primitive{props: Properties.boolean}
	i8_   = Primitive{props: Properties.integer}
	i16_  = Primitive{props: Properties.integer}
	// i32_ = Primitive{props: .integer}
	int_  = Primitive{props: Properties.integer}
	i64_  = Primitive{props: Properties.integer}
	u8_   = Primitive{props: Properties.integer | Properties.unsigned}
	// byte_ = Primitive{props: Properties.integer | Properties.unsigned}
	// byte_ = Alias{parent_type: u8_}
	u16_  = Primitive{props: Properties.integer | Properties.unsigned}
	u32_  = Primitive{props: Properties.integer | Properties.unsigned}
	u64_  = Primitive{props: Properties.integer | Properties.unsigned}
	f16_  = Primitive{props: Properties.float}
	f32_  = Primitive{props: Properties.float}
)

pub fn init_universe() &Scope {
	// universe scope
	mut universe := &Scope{parent: 0}
	universe.register('bool', bool_)
	universe.register('i8', i8_)
	universe.register('i16', i16_)
	universe.register('int', int_)
	universe.register('i64', i64_)
	universe.register('u8', u8_)
	// universe.register('byte', byte_)
	universe.register('u16', u16_)
	universe.register('u64', u64_)
	universe.register('f16', f16_)
	universe.register('f32', f32_)
	return universe
}