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
		println('anon_fn_1')
		return 1
	}]
	struct_a := StructA{field_a: 1, field_b: 'v'}
	assoc_a := {struct_a|field_a: 111}
	call_a := fn_a('string', 1)
	call_b := fn_b('string', 1, a, b)
	call_c := array_init_c[0](1)
	call_d := struct_a.method_a('string', 1)
	call_e := struct_a.field_c(1)
	index_a := foo.bar[1]
	for val_a in list_a {
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
	*deref_assign_a = 2
	sumtype_a := SumTypeA(111)
	match sumtype_a {
		StructA { println('StructA') }
		int { println('int') }
		string { println('string') }
	}
	unsafe {
		mut ptr_0 := &voidptr(0)
		*ptr_0 = 0
	}
	// unsafe_a := unsafe(a++)
	unsafe_b := unsafe { d := 1 d++ d+ d }
	ubsafe_c := unsafe {
		d := 1
		d++
		d
	}
	fn_a('string', unsafe {*deref_a})
}
