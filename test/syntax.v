// this file is just to test the parser so there may be a
// bunch of stuff in here that does not really make sense
[has_globals]
module main

import mod_a
import mod_b.submod_a
import mod_c { sym_a, TypeA, TypeB[T] }

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
type SumTypeA = StructA | int | string | []string

pub type DatabasePool[T] = fn (tid int) T

// we don't want this to be parsed as:
// `type FnA = fn() fn...`
type FnA = fn()
fn fn_after_type_fn_a() int {}
// we don't want this to be parsed as:
// `type FnA = fn() ?fn...`
type FnB = fn() ?
fn fn_after_type_fn_b() int {}

pub const const_array_followed_by_attribute_a = ['a', 'b']
[attribute_after_array_init]
fn fn_with_attribute_after_array_init() { println('v') }

[attribute_a]
enum EnumA {
	value_a
	value_b
	value_c = 2
}

[attribute_a: 'attribute_a_val'; attribute_b]
[attribute_c: 'attribute_c_val']
[attribute_d]
['/product/edit'; post]
struct StructA {
	field_a int
	field_b string
	field_c fn(int) int
	field_d string = 'foo'
	field_e int = 1 + 2 + (4*4)
	// NOTE: no point doing any trickery to try and fix these cases
	// when the attribute syntax is updated everything will just work
	// TODO: uncomment when attribute syntax is updated
	// field_f string = 'bar' [attribute_a; attribute_b]
	// field_g int = 111 [attribute_a; attribute_b]
	// field_h int = field_h_default() [attribute_a]
}

fn StructA.static_method_a() int {
	return 1
}

// TODO: modifiers
struct StructB {
	StructA // embedded
mut:
	field_a int
	field_b string
}

struct StructC {
	field_a shared int
	field_b shared []int = [0]
}

struct C.StructA {}

interface InterfaceA {
	field_a string
	method_a() string
	method_b(string) string
}

// TODO: modifiers
interface InterfaceB {
	InterfaceA // embedded
mut:
	method_a(string) string
}

interface InterfaceGenericA[T] {
	field_a T
}

fn C.external_fn_a(arg_a int) int

[attribute_a: 'attribute_a_val'; attribute_b]
[attribute_c: 'attribute_c_val']
[attribute_d]
fn fn_a(arg_a string, arg_b int) int {
	println('fn_a($arg_a, $arg_b)')
	return 1
}

// TODO: error on missing name/type
// fn fn_b(arg_a string, arg_b, arg_c, arg_d int) int {
fn fn_b(arg_a string, arg_b int, arg_c int, arg_d int) int {
	println('fn_b($arg_a, $arg_b, $arg_c, $arg_d)')
	return 1
}

fn fn_c(arg_a [][]StructA, arg_b [4]StructA) [][]StructA {
	println('fn_b($arg_a, $arg_b)')
	return arg_a
}

fn fn_d(arg_a GenericStructA[int], arg_b moda.GenericStructA[int]) {
	println('fn_d($arg_a, $arg_b)')
}

fn C.fn_d(GenericStructA[int], moda.GenericStructA[int])

fn fn_optional_a() ?int {
	return 1
}

fn fn_optional_b() ?int {
	return fn_optional_a()?
}

fn fn_opt_c() ?int {
	return fn_optional_a()!
}

fn fn_result_a() ! {
	return 1
}

fn fn_result_b() !int {
	return 1
}


fn fn_multi_return_a() (int, int) {
	return 1,2
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

// TODO: operator overload (last missing parser feature, I think :D)
pub fn (a StructA) == (b StructA) bool {
	return a.field_a == b.field_a
}

fn channel_test(arg_a chan string) {
	ch := chan int{cap: 20}
	ch <- 111
	rec := <-ch
}

fn spawn_test() {
	t := spawn fn() {
		for i in 0..100 {
			println('$i...')
		}
	}()
	t.wait()
}

fn fn_result_a() !int {
	array_a := [1,2,3,4]
	return  array_a[0]!
}

fn main_a() {
	a := 1
	b, c := 1, 2
	array_init_a := [1,2,3,4]
	array_init_b := [1,2,3,4]!
	array_init_c := [array_init_a]
	array_init_d := []string{len: 2, cap: 2}
	array_init_e := [][]string{}
	array_init_f := [2][]int{init:[1]}
	array_init_g := [2][][][][]int{}
	array_init_h := [2][][][][2]int{}
	// TODO: better error for missing `]`
	// array_init_i := [['a','b','c','d']
	array_init_i := [['a','b','c','d']]
	array_init_j := []&StructA{}
	array_init_k := [fn(arg_a int) int { return 1 }]
	array_init_i := [fn() int { return 1 }()]
	array_init_thread_a := []thread int{cap: 16}
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
	// NOTE: no longer supported. will error
	// assoc_old_a := {struct_a|field_a: 111}
	// assoc_old_b := {
	// 	...struct_a
	// 	field_a: 1
	// }
	assoc_current_a := StructA{
		...struct_a
		field_a: 1
	}
	string_literal_v_a := 'string literal a'
	string_literal_v_b := "string literal b"
	string_literal_c_a := c'c string literal a'
	string_literal_raw_a := r'string $literal raw a'
	thred_init_a := thread int{cap: 20}
	call_a := fn_a('string', 1)
	call_b := fn_b('string', 1, a, b)
	call_c := array_init_g[0](1)
	call_d := struct_a.method_a('string', 1)
	call_e := struct_a.field_c(1)
	call_f := array_init_k[0]()
	call_g := array_init_k[fn() { return 0 }()]()
	call_h := array_init_k[array_init_b[0]]()
	call_comptime_a := $fn_a('string', 1)
	// comptime call as expr stmt only
	$fn_a('string', 1)
	$compile_warn('compile warn')
	cast_a := u8(1)
	cast_b := &[]u8([1,2,3,4])
	// the following casts should error later about not being
	// able to cast array types, unless it gets implemented.
	cast_c := []u8([1,2,3,4])
	cast_d := [][][]u8([[[1,2,3,4]]])
	cast_d := ?&?int(a)
	fn_literal_a := fn(param_a int, param_b int) int {
		return param_a+param_b
	}
	fn_literal_call_a := fn_literal_a(2, 4)
	fn_literal_direct_call_a := fn(param_a int, param_b int) int {
		return param_a+param_b
	}(2, 4)
	fn_literal_capturing_vars_a := fn [infix_a, infix_b] (param_a int, param_b int) int {
		return (infix_a+infix_b)*(param_a+param_b)
	}
	fn_literal_capturing_vars_direct_call_a := fn [infix_a, infix_b] (param_a int, param_b int) int {
		return (infix_a+infix_b)*(param_a+param_b)
	}(2, 4)
	index_a := array_init_a[0]
	index_a := array_init_a[a]
	index_b := struct_a.field_b[1]
	index_c := [StructA{}][0] // direct index after init
	index_d := [[1,2,3,4]][0][1] // unlimited chaining (add more examples)
	index_e := [fn() []StructA { return [fn() []StructA { return [StructA{}] }()][0] }()[0]][0] // more chaining
	index_f := fn() []string { return ['a', 'b'] }()[0]
	index_g := array_init_e[0] or { ['e', 'f'] }[0]
	index_range_a := array_init_a[0..2]
	index_range_b := array_init_a[2..]
	index_range_c := array_init_a[..2]
	index_range_d := array_init_a[1+2..1+2]
	index_range_e := array_init_a[1+2..]
	index_range_f := array_init_a[..1+2]
	index_range_g := array_init_a[1+2...1+2]
	index_range_h := array_init_a[1+2...]
	index_range_i := array_init_a[...1+2]
	index_range_j := [[1,2,3,4]][0][2..4]
	index_range_k := [[1,2,3,4]][0][2...4]
	index_or_a := array_init_a[0] or { 1 }
	index_or_b := array_init_c[0] or { [5,6,7,8] }[0]
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
	prefix_optional_a := ?mod_a.StructA{}
	prefix_optional_b := ?mod_a.StructA(none)
	if res := fn_optional_a() {
		println('if guard: $res')
	}
	// NOTE: can be easily allowed if needed
	// if res2, res2 := fn_optional_a(), fn_optional_b() {
	// 	println('why? lol')
	// }
	if val := array_init_a[0] {
		println(val)
	}
	if err == IError(MyError{}) {
		println('err == IError(MyError{})')
	}
	if struct_init_a == (StructA{}) {
		println('struct_init_a == (StructA{})')
	}
	// TODO: tricky
	// if struct_init_a == StructA{} {
	// 	println('struct_init_a == StructA{}')
	// }
	// if StructA{} == StructA{} {
	// 	println('StructA{} == StructA{}')
	// }
	if a == 1 {
		println('1 a == $s')
	}
	else if a == 2 {
		println('2 a == $s')
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
	if a > 0 { StructA{} } else { StructB{} }.method_a()
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
	for val_a in array_init_a {
		println(val_a)
	}
	// TODO: error (unless first 2 are allowed? 0..10 and 0..infinity)
	// the third one definitely needs to error
	// for val_a in ..10 {}
	// for val_a in 0.. {}
	// for val_a in .. {}
	for val_a in 0..10 {
		println(val_a)
	}
	for key_a, val_a in array_init_a {
		println(key_a)
		println(val_a)
	}
	for key_a, mut val_a in array_init_a {
		println(key_a)
		println(val_a)
	}
	for idx_a in 0 .. a + 1 {
		println(idx_a)
	}
	for key, value in {
		'a': 'apple'
		'b': 'bananna'
	} {
		println('${key}: ${value}')
	}
	for mut left_node is ast.InfixExpr {
		if left_node.op == .and && mut left_node.right is ast.InfixExpr {
			if left_node.right.op == .key_is {
				println('xx')
			}
		}
	}
	for idx_a:=0; idx_a<=100; idx_a++ {
		println(idx_a)
	}
	for idx_a:=0; idx_a<=100; {
		idx_a++
		println(idx_a)
	}
	// currently erroring in this case
	// for a := 1 {}
	for ; x < 100; {
		println(x)
	}
	for x < 100 {
		println(x)
	}
	for ; ; { println('infinite loop') }
	for {
		println('infinite loop')
	}
	$for x == 1 {
		println('comptime for')
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
	sumtype_a := SumTypeA(111)
	as_cast_a := sumtype_a as int
	match sumtype_a {
		StructA { println('StructA') }
		int { println('int') }
		string { println('string') }
		[]string { println('[]string') }
	}
	mut ptr_a := &voidptr(0)
	unsafe {
		*ptr_a = 0
		(*ptr_a) = *ptr_a - 1
		((*ptr_a)) = *ptr_a - 1
		*(ptr_a) = *ptr_a - 1
		*((ptr_a)) = *ptr_a - 1
		(*(ptr_a)) = *ptr_a - 1
	}
	mut ptr_b := &voidptr(0)
	unsafe {
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

	// REMOVE BELOW - TEMP TESTING OR MOVE TO APPRIPRIATE PLACE ABOVE

	x.member.free()
	x.member.submember1.free()
	x.member.submember1.submember2.free()
	x.y = cmdline.option(current_args, arg, '10').int()
	x.y = cmdline.option(current_args, arg, 
	'10').int()

	assert 'href="${url('/test')}"' == 'href="/test.html"'
	assert '"${show_info('abc')}"' == '"abc"'

	// TODO: confirm there are no cases where
	// there is ambiguity with `|` infix expr
	// lines_indents := lines
	//     .filter(|line| !line.is_blank())``
	//     .map(|line| line.indent_width())

	// TODO: 
	for mut x is MyType {
		println(x)
	}

	ms := t.swatches[name].elapsed().microseconds()

	if !v.pref.is_bare && v.pref.build_mode != .build_module
		&& v.pref.os in [.linux, .freebsd, .openbsd, .netbsd, .dragonfly, .solaris, .haiku] {
	}

	rng.shuffle[T](mut res, config_)!
}
