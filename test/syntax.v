module main

#include <header_a.h>
#flag -L lib_a

__global (
	global_a string
	global_b = 'global_b_value'
)

const (
	const_a = 1
	const_b = 'two'
)

enum EnumA {
	value_a
	value_b
	value_c = 111
}

struct StructA {
	field_a int
	field_b string
	field_c fn(int) int // FIXME
	field_d int = 111
	field_e int [attribute_a]
}

type SumTypeA = StructA | int | string

fn C.external_fn_a(arg_a int) int

fn fn_a(arg_a string, arg_b int) int {
	println('fn_a($arg_a, $arg_b)')
	return 1
}

fn fn_b(arg_a string, arg_b, arg_c, arg_d int) int {
	println('fn_b($arg_a, $arg_b, $arg_c, $arg_d)')
	return 1
}

fn (rec &StructA) method_a(arg_a string, arg_b int) int {
	println('StructA.method_a($arg_a, $arg_b)')
	return 1
}

// TODO: operator overload
pub fn (a StructA) == (b StructA) bool {
	return a.field_a == b.field_a
}

fn main_a() {
	a := 1
	b, c := 1, 2
	array_init_a := [1,2,3,4]
	array_init_b := []string{len: 2, cap :2}
	array_init_c := [][][][]string{}
	array_init_d := [fn(arg_a int) int {
		println('array_init_c[0]($arg_a)')
		return 1
	}]
	map_init_long_string_string := map[string]string{}
	map_init_long_string_array_string := map[string][]string{}
	map_init_short_string_string := {'key_a': 'value_a'}
	map_init_short_string_array_string := {'key_a': ['value_a', 'value_b']}
	struct_a := StructA{field_a: 1, field_b: 'v'}
	// this is parsed as: StructInit{ExprList{Infix{'|'}}}, not intentional, remove?
	assoc_old_a := {struct_a|field_a: 111}
	assoc_current_a := {...struct_a field_a: 111}
	call_a := fn_a('string', 1)
	call_b := fn_b('string', 1, a, b)
	call_c := array_init_c[0](1)
	call_d := struct_a.method_a('string', 1)
	call_e := struct_a.field_c(1)
	index_a := array_init_a[1]
	index_b := struct_a.field_b[1]
	index_range_a := array_init_a[0..2]
	index_range_b := array_init_a[2..]
	index_range_c := array_init_a[..2]
	index_or_a := array_init_a[1] or {
		5
	}
	for val_a in list_a {
		println(val_a)
	}
	for val_a in 0..10 {
		println(val_a)
	}
	for key_a, val_a in list_a {
		println(key_a)
		println(val_a)
	}
	for key_a, mut val_a in list_a {
		println(key_a)
		println(val_a)
	}
	for idx_a:=0; idx_a<=100; idx_a++ {
		println(idx_a)
	} 
	infix_a := 1 * 2
	infix_b := infix_a * 4 * 2 + 11 / 2
	infix_and_par_a := ((((infix_b + 1) * 2) + 111) * 2) / 2
	mut ptr_a := &voidptr(0)
	*ptr_a = 0
	(*ptr_a) = *ptr_a - 1
	sumtype_a := SumTypeA(111)
	match sumtype_a {
		StructA { println('StructA') }
		int { println('int') }
		string { println('string') }
	}
	unsafe {
		mut ptr_b := &voidptr(0)
		*ptr_b = 0
	}
	unsafe_a := unsafe { d := 1 d++ d }
	unsafe_b := unsafe {
		d := 1
		d++
		d
	}
	fn_a('string', unsafe {*ptr_a})
	{
		block_test_a := 1
	}
}
