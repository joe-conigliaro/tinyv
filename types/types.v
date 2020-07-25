module types

pub type Type = Primitive | Pointer | Enum | Struct

[flag]
enum Properties {
	boolean
	float
	integer
	unsigned
	untyped
}

enum PrimitiveKind {
	i8_
	i16_
	// i32_
	int_
	i64_
	u8_
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
	props Properties
}

struct Pointer{
	base Type
}

struct Enum{

}

struct Struct{

}