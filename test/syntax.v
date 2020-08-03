module main

#include <header_a.h>
#flag -L lib_a

__global global_a string

const (
	const_a = 1
	const_b = 'two'
)

enum EnumA {
	value_a
	value_b
}

struct StructA {
	field_a int
	field_b string
	field_c fn(int) int
}

type SumTypeA = StructA | int | string

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

fn main_a() {
	a := 1
	b, c := 1, 2
	array_init_a := [1,2,3,4]
	array_init_b := []string{len: 2, cap :2}
	array_init_c := [fn(arg_a int) int {
		println('array_init_c[0]($arg_a)')
		return 1
	}]
	struct_a := StructA{field_a: 1, field_b: 'v'}
	assoc_a := {struct_a|field_a: 111}
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
	for idx_a:=0; idx_a<=100; idx_a++ {
		println(idx_a)
	} 
	infix_a := 1 * 2
	infix_b := infix_a * 4 * 2 + 11 / 2
	infix_and_par_a := ((((infix_b + 1) * 2) + 111) * 2) / 2
	mut ptr_a := &voidptr(0)
	*ptr_a = 0
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
}
