module types

pub type Object = Enum | Number | Struct

pub struct Type{
	// object &Object // in union sum type implementation we will use pointer
	object    Object
	ptr_count int // nr muls
}

struct Enum{

}

struct Number{

}

struct Struct{

}