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
	b, c := 1, 2
	array_init_a := [1,2,3,4]
	array_init_b := []string{len: 2, cap :2}
	call_a := foo()
	call_b := foo('string', 1, a, b)
	call_c := foo[1]('string', 1, a, b)
	index_a := foo.bar[1]
	struct_a := StructA{field_a: 1, field_b: 'v'}
	assoc_a := {struct_a|field_a: 111}
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
	call_with_unsafe_as_arg_a('string', unsafe {*deref_a})
}

fn (rec &Foo) method_a() {
	println('hello from method_a')
}

