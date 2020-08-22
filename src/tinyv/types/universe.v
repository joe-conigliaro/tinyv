module types

const(
	// TODO: v: allow initialising flags like so: `.integer | .unsigned`
	bool_ = Primitive{props: int(Properties.boolean)}
	i8_   = Primitive{props: int(Properties.integer)}
	i16_  = Primitive{props: int(Properties.integer)}
	// i32_ = Primitive{props: .integer}
	int_  = Primitive{props: int(Properties.integer)}
	i64_  = Primitive{props: int(Properties.integer)}
	// u8_ = Primitive{props: .integer | .unsigned}
	byte_ = Primitive{props: int(Properties.integer) | int(Properties.unsigned)}
	u16_  = Primitive{props: int(Properties.integer) | int(Properties.unsigned)}
	u32_  = Primitive{props: int(Properties.integer) | int(Properties.unsigned)}
	u64_  = Primitive{props: int(Properties.integer) | int(Properties.unsigned)}
	f16_  = Primitive{props: int(Properties.float)}
	f32_  = Primitive{props: int(Properties.float)}
)

fn init_universe() &Scope {
	// universe scope
	mut universe := &Scope{parent: 0}
	universe.register('bool', bool_)
	universe.register('i8', i8_)
	universe.register('i16', i16_)
	universe.register('int', int_)
	universe.register('i64', i64_)
	universe.register('byte', byte_)
	universe.register('u16', u16_)
	universe.register('u64', u64_)
	universe.register('f16', f16_)
	universe.register('f32', f32_)
	return universe
}