module main

struct StructA {
	field_a int
	field_b string
}

fn fn_a() {
    a, b := 1, 2
	arr_a := [1,2,3,4]
	arr_b := []string{len: 2, cap :2}
	call_a := foo[1]()
	index_a := foo.bar[1]
	assoc_a := {struct_a|fa: fva}
	for key_a, val_a in list_a {
		println(key_a)
		println(val_a)
	}
	// TODO:
	infix_a := 1 * 2
	*deref_assign_a = 2
}

fn (rec &Foo) method_a() {
	println('hello from method_a')
}

