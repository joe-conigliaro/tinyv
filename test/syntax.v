// this file is just to test the parser so there may be a
// bunch of stuff in here that does not really make sense
[has_globals]
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

type AliasA = int
type SumTypeA = StructA | int | string

// we don't want this to be parsed as:
// `type FnA = fn() fn...`
type FnA = fn()
fn fn_after_type_fn_a() int {}
// we don't want this to be parsed as:
// `type FnA = fn() ?fn...`
type FnB = fn() ?
fn fn_after_type_fn_b() int {}

[attribute_a]
enum EnumA {
	value_a
	value_b
	value_c = 2
}

[attribute_a: 'attribute_a_val'; attribute_b]
[attribute_c: 'attribute_c_val']
[attribute_d]
struct StructA {
	field_a int
	field_b string
	field_c fn(int) int
	field_d int = 111
	field_e int [attribute_a]
}

struct GenericStructA<T> {
	field_a T
}

struct GenericStructB<T,U> {
	field_a T
	field_b U
}

struct C.StructA {}

fn C.external_fn_a(arg_a int) int

[attribute_a: 'attribute_a_val'; attribute_b]
[attribute_c: 'attribute_c_val']
[attribute_d]
fn fn_a(arg_a string, arg_b int) int {
	println('fn_a($arg_a, $arg_b)')
	return 1
}

fn fn_b(arg_a string, arg_b, arg_c, arg_d int) int {
	println('fn_b($arg_a, $arg_b, $arg_c, $arg_d)')
	return 1
}

fn fn_c(arg_a [][]StructA, arg_b [4]StructA) [][]StructA {
	println('fn_b($arg_a, $arg_b)')
	return arg_a
}

fn fn_opt_a() ?int {
	return 1
}

fn fn_opt_b() ?int {
	return fn_opt_a()?
}

fn fn_opt_c() ?int {
	return fn_opt_a()!
}

fn fn_multi_return_a() (int, int) {
	return 1,2
}

fn fn_generic_a<T>(arg_a T, arg_b string, arg_c int) int {
	println('fn_generic_a: $arg_a.type')
}

fn fn_generic_b<T,Y>(arg_a T, arg_b Y) int {
	fn_generic_b<int,int>(1,2)
	fn_generic_c<fn<U,I>(U, I) U, I>(fn<U,I>(param_a U, param_b I) U {}, 1)

	fn_generic_b<StructA<Y>,int>(StructA<int>{}, 1)
	fn_generic_b<StructA<Y>,StructA<Y> >(StructA<int>{}, 1)
	struct_a := GenericStructA<int>{field_a: 1}
	struct_b := GenericStructB<int,int>{field_a: 1, field_b: 2}
	// possible should we need
	assoc_struct_b := GenericStructB<int,int>{
		...struct_b
		field_a: 10
		field_b: 20
	}

	fn_generic_b<[]string,map[string]string{}>(1, 1)
	fn_('a', a < b, a < b, c)
	fn_('a', foo: a < b, a < b, c)
	fn_b('a', fn_generic_c<fn<T,Y>(int),int>(1))
	fn_b('a', fn_generic_c<fn<T,Y>(int),int>(a < if (fn_generic_b<int,int>(1,2) > 2) { 1 } else { 2 }, 2), 1)
	fn_b('a', moda.fn_generic_b<fn<T,Y>(int),int>(a < if (fn_generic_b<int,int>(1,2) > 2) { 1 } else { 2 }, 2), fn_generic_b<int,int>(1,2))
	fn_b('a', modb.submodb.fn_generic_b<int,int>(fn_generic_b<int,int>(fn_generic_b<int,int>(1,2) < (fn_generic_b<int,int>(1,2) - 2), 2)),fn_generic_b<int,int>(1,2))
	
	fna(fn_generic_b<GenericStructB<int,int>>(GenericStructB<int>{}, 1), moda.fn_generic_b<GenericStructB<int,int>>(GenericStructB<int>{}, 1)) // NOTE: `>>` works here as there is no leading infix
	fna(a < fn_generic_b<GenericStructB<GenericStructA<int>,int> >(GenericStructB<int>{}, 1), moda.fn_generic_b<GenericStructB<int,int> >(GenericStructB<int>{}, 1)) // TODO: `>>` and `>>>` don't work with leading infix
	
	return if x < 64 { fn_generic_b<int,int>(1,2) } else { fn_generic_b<int,int>(1, 2) < (fn_generic_b<int,int>(1, 2) - 2) }
	return fn_generic_b<int,int>(1, 2) < b, c > d, e < f, g > h, fn_generic_b<int,int>(fn_generic_b<int,int>(fn_generic_b<int,int>(1, 2), 2), 2) > j, k < l, m
	
	return a < b, a < fn_generic_b<GenericStructB<int,string>,StructB<int,StructB<u32,u64> > >(1, 1) // TODO: `>>` and `>>>` don't work with leading infix
	return a < b, c < d, GenericStructB<int,int>{field_a: 1, field_b: 2}
	return a < b, c > d, e, f
	return f < g, h < i, j > k 
	return a < b, c, d > e, f < g, h < i, j > k
	return a < b, c > d, e < f, g > h, i > j, k < l, m
	return a < []string{}, a < b, c
	return fn_generic_b<int, string>(1, 2), 2
}

fn fn_generic_c<fn<U,I>(U, I) U ,Y>(arg_a T, arg_b Y) int {
	println('fn_generic_c')
	return 1
}

fn fn_variadic_a(arb_a int, arg_b ...string) {
	fn_variadic_b(...arg_b)
	fn_variadic_b(...['a', 'b', 'c', 'd'])
}

fn fn_variadic_b(arg_a ...string) {
	println(arg_a)
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
	array_init_b := [1,2,3,4]!
	array_init_c := [array_init_a]
	array_init_d := []string{len: 2, cap :2}
	array_init_e := [][]string{}
	array_init_f := [2][]int{init:[1]}
	array_init_g := [2][][][][]int{}
	array_init_h := [2][][][][2]int{}
	array_init_i := [['a','b','c','d']]
	array_init_j := []&StructA{}
	array_init_k := [fn(arg_a int) int {
		println('array_init_c[0]($arg_a)')
		return 1
	}]
	expr_a expr_b // TODO: error
	map_init_long_string_string := map[string]string{}
	map_init_long_string_array_string := map[string][]string{}
	mut map_init_short_string_string := {'key_a': 'value_a'}
	map_init_short_string_string = {} // test empty
	map_init_short_string_array_string := {'key_a': ['value_a', 'value_b']}
	map_init_short_ident_string := {key_a: 'value_a'} // unsupported key type
	struct_init_a := StructA{field_a: 1, field_b: 'v'}
	struct_init_b := foo.StructA{field_a: 1, field_b: 'v'}
	struct_init_c := StructA{1, 'v'}
	// NOTE: no longer supported
	// assoc_old_a := {struct_a|field_a: 111}
	// assoc_old_b := {
	// 	...struct_a
	// 	field_a: 1
	// }
	assoc_current_a := StructA{
		...struct_a
		field_a: 1
	}
	call_a := fn_a('string', 1)
	call_b := fn_b('string', 1, a, b)
	call_c := array_init_g[0](1)
	call_d := struct_a.method_a('string', 1)
	call_e := struct_a.field_c(1)
	call_generic_a := fn_generic_a<StructA>(StructA{}, 'string', 1)
	cast_a := u8(1)
	cast_b := &[]u8([1,2,3,4])
	// the following casts should error later about not being
	// able to cast array types, unless it gets implemented.
	cast_c := []u8([1,2,3,4])
	cast_d := [][][]u8([[[1,2,3,4]]])
	index_a := array_init_a[1]
	index_b := struct_a.field_b[1]
	index_c := [StructA{}][0] // direct index after init
	index_d := [[1,2,3,4]][0][1] // unlimited chaining (add more examples)
	index_e := [fn() []StructA { return [fn() []StructA { return [StructA{}] }()][0] }()[0]][0] // more chaining
	index_f := fn() []string { return ['a', 'b'] }()[0]
	index_g := array_init_e[0] or { ['e', 'f'] }[0]
	index_range_a := array_init_a[0..2]
	index_range_b := array_init_a[2..]
	index_range_c := array_init_a[..2]
	index_range_d := [[1,2,3,4]][0][2..4]
	index_or_a := array_init_a[0] or { 1 }
	index_or_b := array_init_b[0] or { [5,6,7,8] }[0]
	index_or_c := fn() []int { return [array_init_a[0] or { 1 }] }()[0] or { 1 }
	index_or_d := match index_a {
		int { array_init_a }
		else { [5,6,7,8] }
	}[0] or { 1 }
	infix_a := 1 * 2
	infix_b := 1 + 2 * 3 / 4 + 5
	infix_c := infix_a * 4 * 2 + 11 / 2
	infix_d := a == b && c == d
	infix_and_par_a := ((((infix_b + 1) * 2) + 111) * 2) / 2
	prefix_a := &StructA{}
	prefix_b := &&StructA{}
	prefix_c := -infix_a + 2
	closure_a := fn [infix_a, infix_b] () int {
		return infix_a+infix_b
	}
	if a == 1 {
		println('a == $s')
	}
	else if a == 2 {
		println('a == $s')
	}
	else {
		println('a == $s')
	}
	if (if a > 0 {
		1
	} else {
		2
	}) < 2 {
		println('if expr in if cond < 2')
	}
	$if linux {
		println('linux')
	}
	$else $if windows {
		println('windows')
	}
	$else {
		println('other')
	}
	$if option_a ? {
		println('custom option: `v -d option_a`')
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
	for idx_a:=0; idx_a<=100; {
		idx_a++
		println(idx_a)
	}
	for x < 100 {
		println(x)
	}
	for {
		println('infinate loop')
	}
	for_label_a: for i := 4; true; i++ {
		println(i)
		for {
			if i < 7 {
				continue for_label_a
			} else {
				break for_label_a
			}
		}
	}
	mut ptr_a := &voidptr(0)
	*ptr_a = 0
	(*ptr_a) = *ptr_a - 1
	((*ptr_a)) = *ptr_a - 1
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
	unsafe_a := unsafe { mut d := 1 d++ d }
	unsafe_b := unsafe {
		mut d := 1
		d++
		d
	}
	shared arr_string_shared := []String{}
	lock arr_string_shared {
		arr_string_shared << 'a'
	}
	fn_a('string', unsafe {*ptr_a})
	{
		block_test_a := 1
	}
}
