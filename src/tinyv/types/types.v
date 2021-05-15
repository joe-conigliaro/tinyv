module types

// TODO: fix nested sum type in tinyv (like TS)
pub type Type = Primitive | Array | Enum | Map | Pointer | Struct

[flag]
enum Properties {
	boolean
	float
	integer
	unsigned
	untyped
}

enum PrimitiveKind {
	bool_
	i8_
	i16_
	// i32_
	int_
	i64_
	// u8_
	byte_
	u16_
	u32_
	u64_
	untyped_int
	untyped_float
}

struct Primitive {
	kind  PrimitiveKind
	// props Properties
	props int
}

struct Array {
	elem_type Type
}

struct Enum {
	name string
}

struct Map {
	key_type   Type
	value_type Type
}

struct Pointer {
	base Type
}

struct Struct {
	name string
}