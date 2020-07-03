module token

// pub struct Token {
// pub:
//     kind    Kind // the token number/enum; for quick comparisons
//     lit     string // literal representation of the token
//     line_nr int // the line number in the source where the token occured
//     // name_idx int // name table index for O(1) lookup
//     pos     int // the position of the token in scanner text
//     len     int // length of the literal
// }

const (
	key_tokens = {
		'assert': Token.key_assert,
		'struct': Token.key_struct,
		'if': Token.key_if,
		// 'it': Token.key_it,
		'else': Token.key_else,
		'asm': Token.key_asm,
		'return': Token.key_return,
		'module': Token.key_module,
		'sizeof': Token.key_sizeof,
		'go': Token.key_go,
		'goto': Token.key_goto,
		'const': Token.key_const,
		'mut': Token.key_mut,
		'type': Token.key_type,
		'for': Token.key_for,
		'switch': Token.key_switch,
		'fn': Token.key_fn,
		'true': Token.key_true,
		'false': Token.key_false,
		'continue': Token.key_continue,
		'break': Token.key_break,
		'import': Token.key_import,
		'embed': Token.key_embed,
		'unsafe': Token.key_unsafe,
		'typeof': Token.key_typeof,
		'enum': Token.key_enum,
		'interface': Token.key_interface,
		'pub': Token.key_pub,
		'in': Token.key_in,
		'atomic': Token.key_atomic,
		'or': Token.key_orelse,
		'__global': Token.key_global,
		'union': Token.key_union,
		'static': Token.key_static,
		'as': Token.key_as,
		'defer': Token.key_defer,
		'match': Token.key_match,
		'select': Token.key_select,
		'none': Token.key_none,
		'__offsetof': Token.key_offsetof,
		'is': Token.key_is
	}
)

pub enum Token {
	unknown
	eof
	name // user
	number // 123
	string // 'foo'
	str_inter // 'name=$user.name'
	chartoken // `A`
	plus
	minus
	mul
	div
	mod
	xor // ^
	pipe // |
	inc // ++
	dec // --
	and // &&
	logical_or
	not
	bit_not
	question
	comma
	semicolon
	colon
	arrow // =>
	amp
	hash
	dollar
	str_dollar
	left_shift
	right_shift
	not_in // !in
	// at // @
	assign // =
	decl_assign // :=
	plus_assign // +=
	minus_assign // -=
	div_assign
	mult_assign
	xor_assign
	mod_assign
	or_assign
	and_assign
	right_shift_assign
	left_shift_assign
	// {}  () []
	lcbr
	rcbr
	lpar
	rpar
	lsbr
	rsbr
	// == != <= < >= >
	eq
	ne
	gt
	lt
	ge
	le
	comment
	nl
	dot
	dotdot
	ellipsis
	// keywords
	keyword_beg
	key_as
	key_asm
	key_assert
	key_atomic
	key_break
	key_const
	key_continue
	key_defer
	key_else
	key_embed
	key_enum
	key_false
	key_for
	key_fn
	key_global
	key_go
	key_goto
	key_if
	key_import
	key_in
	key_interface
	key_is
	// key_it
	key_match
	key_module
	key_mut
	key_none
	key_return
	key_select
	key_sizeof
	key_offsetof
	key_struct
	key_switch
	key_true
	key_type
	key_typeof
	key_orelse
	key_union
	key_pub
	key_static
	key_unsafe
	keyword_end
	_end_
}

enum BindingPower {
	lowest
	one
	two
	three
	four
	five
	highest
}

pub fn (t Token) left_binding_power() BindingPower {
	match t {
		// `*` |  `/` | `%` | `<<` | `>>` | `&`
		.mul, .div, .mod, .left_shift, .right_shift, .amp {
			return .five
		}
		// `+` |  `-` |  `|` | `^`
		.plus, .minus, .pipe, .xor {
			return .four
		}
		// `==` | `!=` | `<` | `<=` | `>` | `>=`
		.eq, .ne, .lt, .le, .gt, .ge {
			return .three
		}
		.and {
			return .two
		}
		.logical_or {
			return .one
		}
		else {
			return .lowest
		}
	}
}

pub fn (tok Token) is_prefix() bool {
	return tok in [.minus, .amp, .mul, .not, .bit_not]
}

pub fn (tok Token) is_infix() bool {
	return tok in [.plus, .minus, .mod, .mul, .div, .eq, .ne, .gt, .lt, .key_in,
	//
	.key_as, .ge, .le, .logical_or, .xor, .not_in, .key_is, /*.not_is,*/
	//
	.and, /*.dot,*/ .pipe, .amp, .left_shift, .right_shift]
}

pub fn (tok Token) is_postfix() bool {
	return tok in [.inc, .dec]
}
