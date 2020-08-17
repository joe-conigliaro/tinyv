module types

const(
	// universe = &Scope
)

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

fn init() {
	// TODO: scopes
	// universe scope
	universe := {
		'bool': bool_
		'i8': i8_
		'i16': i16_
		'int': int_
		'i64': i64_
		'byte': byte_
		'u16': u16_
		'u64': u64_
		'f16': f16_
		'f32': f32_
	}
}