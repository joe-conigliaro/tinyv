// this file is just to test the parser so there may be a
// bunch of stuff in here that does not really make sense

struct GenericStructA[T] {
	field_a T
}

struct GenericStructB[T,U] {
	field_a T
	field_b U
}

fn test_generic_struct_init() {
	a := GenericStructA[int] {
		field_a: 1
	}
}

fn fn_generic_a[T](arg_a T, arg_b string, arg_c int) int {
	println('fn_generic_a: $arg_a.type, $arg_b.type, $arg_c.type')
	return 1
}

fn fn_generic_b[T,Y](arg_a T, arg_b Y) int {
	println('fn_generic_a: $arg_a.type, $arg_b.type')
}

fn fn_generic_c[fn[U,I](U, I) U, Y](arg_a T, arg_b Y) int {
	println('fn_generic_c')
	return 1
}

fn test_generic_call() {
	call_generic_a := fn_generic_a[StructA](StructA{}, 'string', 1)
}


fn test_generic_init() {
	fn_generic_b[int,int](1,2)
	fn_generic_c[fn[U,I](U, I) U, I](fn[U,I](param_a U, param_b I) U {}, 1)

	fn_generic_b[StructA[Y],int](StructA[int]{}, 1)
	fn_generic_b[StructA[Y],StructA[Y]](StructA[int]{}, 1)
	struct_a := GenericStructA[int]{field_a: 1}
	struct_b := GenericStructB[int,int]{field_a: 1, field_b: 2}
	// possible should we need
	assoc_struct_b := GenericStructB[int,int]{
		...struct_b
		field_a: 10
		field_b: 20
	}

	fn_generic_b[[]string,map[string]string{}](1, 1)
	fn_a('a', a < b, a < b, c)
	fn_a('a', foo: a < b, a < b, c)
	fn_b('a', fn_generic_c[fn[T,Y](int),int](1))
	fn_b('a', fn_generic_c[fn[T,Y](int),int](a < if (fn_generic_b[int,int](1,2) > 2) { 1 } else { 2 }, 2), 1)
	fn_b('a', moda.fn_generic_b[fn[T,Y](int),int](a < if (fn_generic_b[int,int](1,2) > 2) { 1 } else { 2 }, 2), fn_generic_b[int,int](1,2))
	fn_b('a', modb.submodb.fn_generic_b[int,int](fn_generic_b[int,int](fn_generic_b[int,int](1,2) < (fn_generic_b[int,int](1,2) - 2), 2)),fn_generic_b[int,int](1,2))
	
	fn_c(fn_generic_b[GenericStructB[int,int]](GenericStructB<int>{}, 1), moda.fn_generic_b[GenericStructB[int,int]](GenericStructB[int]{}, 1))
	fn_c(a < fn_generic_b[GenericStructB[GenericStructA[int],int]](GenericStructB[int]{}, 1), moda.fn_generic_b[GenericStructB[int,int]](GenericStructB<int>{}, 1))
	
	return if x < 64 { fn_generic_b[int,int](1,2) } else { fn_generic_b[int,int](1, 2) < (fn_generic_b[int,int](1, 2) - 2) }
	return fn_generic_b[int,int](1, 2) < b, c > d, e < f, g > h, fn_generic_b[int,int](fn_generic_b[int,int](fn_generic_b[int,int](1, 2), 2), 2) > j, k < l, m
}

