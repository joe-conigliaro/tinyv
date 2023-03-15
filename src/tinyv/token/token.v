// Copyright (c) 2020-2023 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module token

pub enum Token {
	amp // &
	and // &&
	and_assign // &=
	arrow // <-
	assign // =
	at // @
	bit_not // ~
	char // `A` - rune
	colon // :
	comma // ,
	comment
	dec // --
	decl_assign // :=
	div // /
	div_assign // /=
	dollar // $
	dot // .
	dotdot // ..
	ellipsis // ...
	eof
	eq // ==
	ge // >=
	gt // >
	hash // #
	inc // ++
	key_as
	key_asm
	key_assert
	key_atomic
	key_break
	key_const
	key_continue
	key_defer
	key_dump
	key_else
	key_enum
	key_false
	key_fn
	key_for
	key_global
	key_go
	key_goto
	key_if
	key_import
	key_in
	key_interface
	key_is
	key_isreftype
	key_likely
	key_lock
	key_match
	key_module
	key_mut
	key_nil
	key_none
	key_offsetof
	key_or
	key_pub
	key_return
	key_rlock
	key_select
	key_shared
	key_sizeof
	key_static
	key_struct
	key_true
	key_type
	key_typeof
	key_union
	key_unlikely
	key_unsafe
	key_volatile
	lcbr // {
	le // <=
	left_shift // <<
	left_shift_assign // >>=
	logical_or // ||
	lpar // (
	lsbr // [
	lt // <
	minus // -
	minus_assign // -=
	mod // %
	mod_assign // %=
	mul // *
	mul_assign // *=
	name // user
	ne // !=
	// nilsbr // #[
	nl
	not // !
	not_in // !in
	not_is // !is
	number // 123
	or_assign // |=
	pipe // |
	plus // +
	plus_assign // +=
	question // ?
	rcbr // }
	right_shift // >>
	right_shift_assign // <<=
	right_shift_unsigned // >>>
	right_shift_unsigned_assign // >>>=
	rpar // )
	rsbr // ]
	semicolon // ;
	// str_dollar
	// str_inter // 'name=$user.name'
	string // 'foo'
	unknown
	xor // ^
	xor_assign // ^=
}

pub enum BindingPower {
	lowest
	one
	two
	three
	four
	five
	highest
}

[inline]
pub fn (t Token) left_binding_power() BindingPower {
	return match t {
		// `||`
		.logical_or { .one }
		// `&&`
		.and { .two }
		// `==` | `!=` | `<` | `<=` | `>` | `>=`
		.eq, .ne, .lt, .le, .gt, .ge { .three }
		// `+` |  `-` |  `|` | `^`
		.plus, .minus, .pipe, .xor { .four }
		// `*` |  `/` | `%` | `<<` | `>>` | `>>>` | `&`
		.mul, .div, .mod, .left_shift, .right_shift, .right_shift_unsigned, .amp { .five }
		else { .lowest }
	}
}

// TODO: double check / fix this. just use what is needed instead of this
[inline]
pub fn (t Token) right_binding_power() BindingPower {
	return unsafe{ BindingPower((int(t.left_binding_power()) + 1)) }
}

[inline]
pub fn (t Token) is_prefix() bool {
	return match t {
		.minus, .amp, .mul, .not, .bit_not { true }
		else { false }
	}
}

[inline]
pub fn (t Token) is_infix() bool {
	return match t {
		.plus, .minus, .mod, .mul, .div, .eq, .ne, .gt, .lt,
		.key_in, .key_as, .ge, .le, .logical_or, .xor, .not_in,
		.key_is, .not_is, .and /* .dot, */, .pipe, .amp, .left_shift,
		.right_shift, .right_shift_unsigned { true }
		else { false }
	}
}

[inline]
pub fn (t Token) is_postfix() bool {
	// If we want pratt loop to handle `fn()!` | `fn()?`
	// I will most likely continue doing this manually.
	// return t in [.inc, .dec, .not, .question]
	return match t {
		.inc, .dec { true }
		else { false }
	}
}

[inline]
pub fn (t Token) is_assignment() bool {
	return match t {
		.assign, // =
		.decl_assign, // :=
		.plus_assign, // +=
		.minus_assign, // -=
		.div_assign,
		.mul_assign,
		.xor_assign,
		.mod_assign,
		.or_assign,
		.and_assign,
		.right_shift_assign,
		.left_shift_assign,
		.right_shift_unsigned_assign { true }
		else { false }
	}
}

[inline]
pub fn (t Token) is_overloadable() bool {
	return match t {
		// `+` |  `-` |  `|` | `^`
		.plus, .minus, .pipe, .xor,
		// `==` | `!=` | `<` | `<=` | `>` | `>=`
		.eq, .ne, .lt, .le, .gt, .ge { true }
		else { false }
	}
}

// NOTE: probably switch back to map again later.
// for dev this is easier to see if any tokens are missing.
pub fn (t Token) str() string {
	return match t {
		.amp { '&' }
		.and { '&&' }
		.and_assign { '&=' }
		.arrow { '=>' }
		.assign { '=' }
		.at { '@' }
		.bit_not { '~' }
		.char { 'char' }
		.colon { ':' }
		.comma { ',' }
		.comment { '// comment' }
		.dec { '--' }
		.decl_assign { ':=' }
		.div { '/' }
		.div_assign { '/=' }
		.dollar { '$' }
		.dot { '.' }
		.dotdot { '..' }
		.ellipsis { '...' }
		.eof { 'eof' }
		.eq { '==' }
		.ge { '>=' }
		.gt { '>' }
		.hash { '#' }
		.inc { '++' }
		.key_as { 'as' }
		.key_asm { 'asm' }
		.key_assert { 'assert' }
		.key_atomic { 'atomic' }
		.key_break { 'break' }
		.key_const { 'const' }
		.key_continue { 'continue' }
		.key_defer { 'defer' }
		.key_dump { 'dump' }
		.key_else { 'else' }
		.key_enum { 'enum' }
		.key_false { 'false' }
		.key_fn { 'fn' }
		.key_for { 'for' }
		.key_global { '__global' }
		.key_go { 'go' }
		.key_goto { 'goto' }
		.key_if { 'if' }
		.key_import { 'import' }
		.key_in { 'in' }
		.key_interface { 'interface' }
		.key_is { 'is' }
		.key_isreftype { 'isreftype' }
		.key_likely { '_likely_' }
		.key_lock { 'lock' }
		.key_match { 'match' }
		.key_module { 'module' }
		.key_mut { 'mut' }
		.key_nil { 'nil' }
		.key_none { 'none' }
		.key_offsetof { '__offsetof' }
		.key_or { 'or' }
		.key_pub { 'pub' }
		.key_return { 'return' }
		.key_rlock { 'rlock' }
		.key_select { 'select' }
		.key_shared { 'shared' }
		.key_sizeof { 'sizeof' }
		.key_static { 'static' }
		.key_struct { 'struct' }
		.key_true { 'true' }
		.key_type { 'type' }
		.key_typeof { 'typeof' }
		.key_union { 'union' }
		.key_unlikely { '_unlikely_' }
		.key_unsafe { 'unsafe' }
		.key_volatile { 'volatile' }
		.lcbr { '{' }
		.le { '<=' }
		.left_shift { '<<' }
		.left_shift_assign { '<<=' }
		.logical_or { '||' }
		.lpar { '(' }
		.lsbr { '[' }
		.lt { '<' }
		.minus { '-' }
		.minus_assign { '-=' }
		.mod { '%' }
		.mod_assign { '%=' }
		.mul { '*' }
		.mul_assign { '*=' }
		.name { 'name' }
		.ne { '!=' }
		// .nilsbr { '#[' }
		.nl { 'NLL' }
		.not { '!' }
		.not_in { '!in' }
		.not_is { '!is' }
		.number { 'number' }
		.or_assign { '|=' }
		.pipe { '|' }
		.plus { '+' }
		.plus_assign { '+=' }
		.question { '?' }
		.rcbr { '}' }
		.right_shift { '>>' }
		.right_shift_assign { '>>=' }
		.right_shift_unsigned { '>>>' }
		.right_shift_unsigned_assign { '>>>=' }
		.rpar { ')' }
		.rsbr { ']' }
		.semicolon { ';' }
		// .str_dollar { '$2' }
		.string { 'string' }
		.unknown { 'unknown' }
		.xor { '^' }
		.xor_assign { '^=' }
	}
}
