// Copyright (c) 2020-2021 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module token

pub const (
	tokens_str = build_tokens_str()
)

pub enum Token {
	unknown
	eof
	name // user
	number // 123
	string // 'foo'
	str_inter // 'name=$user.name'
	char // `A`
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
	right_shift_unsigned
	not_in // !in
	not_is // !is
	// at // @
	assign // =
	decl_assign // :=
	plus_assign // +=
	minus_assign // -=
	div_assign
	mul_assign
	xor_assign
	mod_assign
	or_assign
	and_assign
	right_shift_assign
	left_shift_assign
	right_shift_unsigned_assign
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
	// key_embed
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
	key_shared
	key_lock
	key_rlock
	key_none
	key_return
	key_select
	key_sizeof
	key_likely
	key_unlikely
	key_offsetof
	key_struct
	// key_switch
	key_true
	key_type
	key_typeof
	key_or
	key_union
	key_pub
	key_static
	key_unsafe
	keyword_end
	_end_
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
	match t {
		// `*` |  `/` | `%` | `<<` | `>>` | `>>>` | `&`
		.mul, .div, .mod, .left_shift, .right_shift, .right_shift_unsigned, .amp {
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
		// `&&`
		.and {
			return .two
		}
		// `||`
		.logical_or {
			return .one
		}
		else {
			return .lowest
		}
	}
}

// TODO: double check / fix this. just use what is needed instead of this
[inline]
pub fn (t Token) right_binding_power() BindingPower {
	return BindingPower((int(t.left_binding_power()) + 1))
}

[inline]
pub fn (tok Token) is_prefix() bool {
	return tok in [.minus, .amp, .mul, .not, .bit_not]
}

[inline]
pub fn (tok Token) is_infix() bool {
	return tok in [.plus, .minus, .mod, .mul, .div, .eq, .ne, .gt, .lt, .key_in, .key_as, .ge,
		.le, .logical_or, .xor, .not_in, .key_is, .not_is, .and /* .dot, */, .pipe, .amp, .left_shift,
		.right_shift, .right_shift_unsigned]
}

[inline]
pub fn (tok Token) is_postfix() bool {
	return tok in [.inc, .dec]
}

[inline]
pub fn (tok Token) is_assignment() bool {
	return tok in [
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
		.right_shift_unsigned_assign,
	]
}

[inline]
pub fn (tok Token) is_overloadable() bool {
	return tok in [
		// `+` |  `-` |  `|` | `^`
		.plus, .minus, .pipe, .xor,
		// `==` | `!=` | `<` | `<=` | `>` | `>=`
		.eq, .ne, .lt, .le, .gt, .ge,
	]
}

// NOTE: add keyword tokens here
pub fn match_keyword_token(name string) Token {
	match name.len {
		2 {
			match name {
				'if' { return .key_if }
				'go' { return .key_go }
				'fn' { return .key_fn }
				'in' { return .key_in }
				'or' { return .key_or }
				'as' { return .key_as }
				'is' { return .key_is }
				else { return .unknown }
			}
		}
		3 {
			match name {
				'asm' { return .key_asm }
				'mut' { return .key_mut }
				'for' { return .key_for }
				'pub' { return .key_pub }
				else { return .unknown }
			}
		}
		4 {
			match name {
				'else' { return .key_else }
				'goto' { return .key_goto }
				'type' { return .key_type }
				'true' { return .key_true }
				'enum' { return .key_enum }
				'lock' { return .key_lock }
				else { return .unknown }
			}
		}
		5 {
			match name {
				'const' { return .key_const }
				'false' { return .key_false }
				'break' { return .key_break }
				'union' { return .key_union }
				'defer' { return .key_defer }
				'match' { return .key_match }
				'rlock' { return .key_rlock }
				else { return .unknown }
			}
		}
		6 {
			match name {
				'assert' { return .key_assert }
				'struct' { return .key_struct }
				'return' { return .key_return }
				'module' { return .key_module }
				'sizeof' { return .key_sizeof }
				'shared' { return .key_shared }
				'import' { return .key_import }
				'unsafe' { return .key_unsafe }
				'typeof' { return .key_typeof }
				'atomic' { return .key_atomic }
				'static' { return .key_static }
				'select' { return .key_select }
				else { return .unknown }
			}
		}
		8 {
			match name {
				'continue' { return .key_continue }
				'__global' { return .key_global }
				else { return .unknown }
			}
		}
		9 {
			match name {
				'interface' { return .key_interface }
				else { return .unknown }
			}
		}
		10 {
			match name {
				'__offsetof' { return .key_offsetof }
				else { return .unknown }
			}
		}
		else {
			return .unknown
		}
	}
}

fn build_tokens_str() []string {
	mut s := []string{len: (int(Token._end_) + 1)}
	s[Token.unknown] = 'unknown'
	s[Token.eof] = 'eof'
	s[Token.name] = 'name'
	s[Token.number] = 'number'
	s[Token.string] = 'string'
	s[Token.char] = 'char'
	s[Token.plus] = '+'
	s[Token.minus] = '-'
	s[Token.mul] = '*'
	s[Token.div] = '/'
	s[Token.mod] = '%'
	s[Token.xor] = '^'
	s[Token.bit_not] = '~'
	s[Token.pipe] = '|'
	s[Token.hash] = '#'
	s[Token.amp] = '&'
	s[Token.inc] = '++'
	s[Token.dec] = '--'
	s[Token.and] = '&&'
	s[Token.logical_or] = '||'
	s[Token.not] = '!'
	s[Token.dot] = '.'
	s[Token.dotdot] = '..'
	s[Token.ellipsis] = '...'
	s[Token.comma] = ','
	s[Token.not_in] = '!in'
	s[Token.not_is] = '!is'
	// s[Token.at] = '@'
	s[Token.semicolon] = ';'
	s[Token.colon] = ':'
	s[Token.arrow] = '=>'
	s[Token.assign] = '='
	s[Token.decl_assign] = ':='
	s[Token.plus_assign] = '+='
	s[Token.minus_assign] = '-='
	s[Token.mul_assign] = '*='
	s[Token.div_assign] = '/='
	s[Token.xor_assign] = '^='
	s[Token.mod_assign] = '%='
	s[Token.or_assign] = '|='
	s[Token.and_assign] = '&='
	s[Token.right_shift_assign] = '>>='
	s[Token.left_shift_assign] = '<<='
	s[Token.right_shift_unsigned_assign] = '>>>='
	s[Token.lcbr] = '{'
	s[Token.rcbr] = '}'
	s[Token.lpar] = '('
	s[Token.rpar] = ')'
	s[Token.lsbr] = '['
	s[Token.rsbr] = ']'
	s[Token.eq] = '=='
	s[Token.ne] = '!='
	s[Token.gt] = '>'
	s[Token.lt] = '<'
	s[Token.ge] = '>='
	s[Token.le] = '<='
	s[Token.question] = '?'
	s[Token.left_shift] = '<<'
	s[Token.right_shift] = '>>'
	s[Token.right_shift_unsigned] = '>>>'
	s[Token.comment] = '// comment'
	s[Token.nl] = 'NLL'
	s[Token.dollar] = '$'
	s[Token.str_dollar] = '$2'
	s[Token.key_assert] = 'assert'
	s[Token.key_struct] = 'struct'
	s[Token.key_if] = 'if'
	// s[Token.key_it] = 'it'
	s[Token.key_else] = 'else'
	s[Token.key_asm] = 'asm'
	s[Token.key_return] = 'return'
	s[Token.key_module] = 'module'
	s[Token.key_sizeof] = 'sizeof'
	s[Token.key_likely] = '_likely_'
	s[Token.key_unlikely] = '_unlikely_'
	s[Token.key_go] = 'go'
	s[Token.key_goto] = 'goto'
	s[Token.key_const] = 'const'
	s[Token.key_mut] = 'mut'
	s[Token.key_shared] = 'shared'
	s[Token.key_lock] = 'lock'
	s[Token.key_rlock] = 'rlock'
	s[Token.key_type] = 'type'
	s[Token.key_for] = 'for'
	// s[Token.key_switch] = 'switch'
	s[Token.key_fn] = 'fn'
	s[Token.key_true] = 'true'
	s[Token.key_false] = 'false'
	s[Token.key_continue] = 'continue'
	s[Token.key_break] = 'break'
	s[Token.key_import] = 'import'
	// s[Token.key_embed] = 'embed'
	s[Token.key_unsafe] = 'unsafe'
	s[Token.key_typeof] = 'typeof'
	s[Token.key_enum] = 'enum'
	s[Token.key_interface] = 'interface'
	s[Token.key_pub] = 'pub'
	s[Token.key_in] = 'in'
	s[Token.key_atomic] = 'atomic'
	s[Token.key_or] = 'or'
	s[Token.key_global] = '__global'
	s[Token.key_union] = 'union'
	s[Token.key_static] = 'static'
	s[Token.key_as] = 'as'
	s[Token.key_defer] = 'defer'
	s[Token.key_match] = 'match'
	s[Token.key_select] = 'select'
	s[Token.key_none] = 'none'
	s[Token.key_offsetof] = '__offsetof'
	s[Token.key_is] = 'is'
	return s
}

pub fn (t Token) str() string {
	return tokens_str[t]
}
