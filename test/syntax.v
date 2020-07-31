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
}

type SumTypeA = StructA | int | string

fn fn_a() {
	a := 1
	a, b := 1, 2
	array_init_a := [1,2,3,4]
	array_init_b := []string{len: 2, cap :2}
	call_a := foo()
	call_b := foo('string', 1, a, b)
	call_c := foo[1]('string', 1, a, b)
	index_a := foo.bar[1]
	assoc_a := {struct_a|fa: fva}
	for val_a in list_a {
		println(val_a)
	}
	for key_a, val_a in list_a {
		println(key_a)
		println(val_a)
	}
	// TODO:
	infix_a := 1 * 2
	*deref_assign_a = 2
	sumtype_a := SumTypeA(111)
	match sumtype_a {
		StructA { println('StructA') }
		int { println('int') }
		string { println('string') }
	}
	unsafe {
		a := 1
		a++
	}
	// unsafe_a := unsafe(a++)
	unsafe_b := unsafe { a := 1 a++ a++ a }
	ubsafe_c := unsafe {
		a := 1
		a++
		a
	}
	call_with_unsafe_as_arg_a('string', unsafe {*deref_a})
}

fn (rec &Foo) method_a() {
	println('hello from method_a')
}
