module scanner

import token
import pref

pub struct Scanner {
	pref   &pref.Preferences
mut:
	text   string
pub mut:
	last_nl_pos int
	line_nr int
	pos     int
	lit     string
}

pub fn new_scanner(pref &pref.Preferences) &Scanner {
	return &Scanner{
		pref: pref
		line_nr: 1
	}
}

pub fn (mut s Scanner) set_text(text string) {
	s.text = text
}

pub fn (mut s Scanner) reset() {
	s.text = ''
	s.last_nl_pos = 0
	s.line_nr = 1
	s.pos = 0
	s.lit = ''
}

pub fn (mut s Scanner) scan() token.Token {
	s.whitespace()
	// if s.pos >= s.text.len-1 {
	if s.pos == s.text.len {
		s.lit = ''
		return .eof
	}
	// defer {
	// 	s.lit = s.text[start_pos..s.pos]
	// }
	// s.lit = ''
	c := s.text[s.pos]
	start_pos := s.pos
	// comment OR `/=` OR `/`
	if c == `/` {
		c2 := s.text[s.pos+1]
		// comment
		if c2 in [`/`, `*`] {
			s.comment()
			s.lit = s.text[start_pos..s.pos]
			return .comment
		}
		// `/=`
		else if c2 == `=` {
			s.pos+=2
			return .div_assign
		}
		s.pos++
		// `/`
		return .div
	}
	// number
	else if c >= `0` && c <= `9` {
		s.number()
		s.lit = s.text[start_pos..s.pos]
		return .number
	}
	// name
	else if (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `_` {
		s.name()
		s.lit = s.text[start_pos..s.pos]
		tok := token.key_tokens[s.lit]
		if tok != .unknown {
			return tok
		}
		return .name
	}
	// string
	else if c in [`'`, `"`] {
		s.string_literal()
		s.lit = s.text[start_pos+1..s.pos-1]
		return .string
	}
	// byte (char) `a`
	else if c == `\`` {
		s.pos++
		// NOTE: if there is more than one char still scan it
		// we can error at a later stage. should we error now?
		for s.text[s.pos] != c {
			if s.text[s.pos] == `\\` {
				s.pos+=2
				continue
			}
			s.pos++
		}
		s.pos++
		s.lit = s.text[start_pos+1..s.pos-1]
		return .char
	}
	s.lit = ''
	s.pos++
	match c {
		`.` {
			if s.text[s.pos] == `.` {
				s.pos++
				if s.text[s.pos] == `.` {
					s.pos++
					return .ellipsis
				}
				return .dotdot
			}
			return .dot
		}
		`:` {
			if s.text[s.pos] == `=` {
				s.pos++
				return .decl_assign
			}
			return .colon
		}
		`!` {
			c2 := s.text[s.pos]
			if c2 == `=` {
				s.pos++
				return .ne
			}
			else if c2 == `i` {
				c3 := s.text[s.pos+1]
				if c3 == `n` {
					s.pos+=2
					return .not_in
				}
				else if c3 == `s` {
					s.pos+=2
					return .not_is
				}
			}
			return .not
		}
		`=` {
			c2 := s.text[s.pos]
			if c2 == `=` {
				s.pos++
				return .eq
			}
			else if c2 == `>` {
				s.pos++
				return .arrow
			}
			return .assign
		}
		`+` {
			c2 := s.text[s.pos]
			if c2 == `+` {
				s.pos++
				return .inc
			}
			else if c2 == `=` {
				s.pos++
				return .plus_assign
			}
			return .plus
		}
		`-` {
			c2 := s.text[s.pos]
			if c2 == `-` {
				s.pos++
				return .dec
			}
			else if c2 == `=` {
				s.pos++
				return .minus_assign
			}
			return .minus
		}
		`%` {
			if s.text[s.pos] == `=` {
				s.pos++
				return .mod_assign
			}
			return .mod
		}
		`*` {
			if s.text[s.pos] == `=` {
				s.pos++
				return .mul_assign
			}
			return .mul
		}
		`^` {
			if s.text[s.pos] == `=` {
				s.pos++
				return .xor_assign
			}
			return .xor
		}
		`&` {
			c2 := s.text[s.pos]
			if c2 == `&` {
				s.pos++
				return .and
			}
			else if c2 == `=` {
				s.pos++
				return .and_assign
			}
			return .amp
		}
		`|` {
			c2 := s.text[s.pos]
			if c2 == `|` {
				s.pos++
				return .logical_or
			}
			else if c2 == `=` {
				s.pos++
				return .or_assign
			}
			return .pipe
		}
		`<` {
			c2 := s.text[s.pos]
			if c2 == `<` {
				s.pos++
				if s.text[s.pos] == `=` {
					s.pos++
					return .left_shift_assign
				}
				return .left_shift
			}
			else if c2 == `=` {
				s.pos++
				return .le
			}
			return .lt
		}
		`>` {
			c2 := s.text[s.pos]
			if c2 == `>` {
				s.pos++
				if s.text[s.pos] == `=` {
					s.pos++
					return .right_shift_assign
				}
				return .right_shift
			}
			else if c2 == `=` {
				s.pos++
				return .ge
			}
			return .gt
		}
		// `@` { return .at }
		`~` { return .bit_not }
		`,` { return .comma }
		`$` { return .dollar }
		`#` { return .hash }
		`{` { return .lcbr }
		`}` { return .rcbr }
		`(` { return .lpar }
		`)` { return .rpar }
		`[` { return .lsbr }
		`]` { return .rsbr }
		`;` { return .semicolon }
		`?` { return .question }
		else { return .unknown }
	}
}

// skip whitespace
fn (mut s Scanner) whitespace() {
	for s.pos < s.text.len {
		c := s.text[s.pos]
		if c == `\r` && s.text[s.pos+1] == `\n` {
			s.last_nl_pos = s.pos
			s.line_nr++
			s.pos+=2
			continue
		}
		else if c in [` `, `\t`, `\n`] {
			if c == `\n` {
				s.last_nl_pos = s.pos
				s.line_nr++
			}
			s.pos++
			continue
		}
		break
	}
}

fn(s &Scanner) comment() {
	s.pos++
	match s.text[s.pos] {
		// single line
		`/` {
			for s.pos < s.text.len {
				if s.text[s.pos] == `\r` && s.text[s.pos+2] == `\n` {
					break
				}
				else if s.text[s.pos] == `\n` {
					break
				}
				s.pos++
			}
		}
		// multi line
		`*` {
			mut ml_comment_depth := 1
			for s.pos < s.text.len {
				c := s.text[s.pos]
				c1 := s.text[s.pos+1]
				if c == `\r` && c1 == `\n` {
					s.last_nl_pos = s.pos
					s.line_nr++
					s.pos+=2
					continue
				}
				else if c == `\n` {
					s.last_nl_pos = s.pos
					s.line_nr++
					s.pos++
					continue
				}
				else if c == `/` && c1 == `*` {
					s.pos+=2
					ml_comment_depth++
					continue
				}
				else if c == `*` && c1 == `/` {
					s.pos+=2
					ml_comment_depth--
					if ml_comment_depth == 0 {
						break
					}
					continue
				}
				s.pos++
			}
		}
		else {}
	}
}

fn (mut s Scanner) string_literal() {
	c := s.text[s.pos]
	s.pos++
	for s.pos < s.text.len {
		c1 := s.text[s.pos]
		// skip escape \n | \'
		if c1 == `\\` {
			s.pos+=2
			continue
		}
		if c1 == c {
			s.pos++
			break
		}
		s.pos++
	}
}

fn (mut s Scanner) number() {
	if s.text[s.pos] == `0` {
		s.pos++
		c := s.text[s.pos]
		// TODO: fix underscore support
		// 0b (binary)
		if c in [`b`, `B`] {
			s.pos++
			for s.text[s.pos] in [`0`, `1`] {
				s.pos++
			}
			return
		}
		// 0x (hex)
		else if c in [`x`, `X`] {
			s.pos++
			for {
				c2 := s.text[s.pos]
				if (c2 >= `0` && c2 <= `9`) || (c2 >= `a` && c2 <= `z`) || (c2 >= `A` && c2 <= `Z`) || c2 == `_` {
					s.pos++
					continue
				}
				return
			}
		}
		// 0o (octal)
		else if c in [`o`, `O`] {
			s.pos++
			for {
				c2 := s.text[s.pos]
				if c2 >= `0` && c2 <= `7` {
					s.pos++
					continue
				}
				return
			}
		}
	}
	mut has_decimal := false
	mut has_exponent := false
	// TODO: proper impl of fraction / expoent
	// continue decimal (and also completion of bin/octal)
	for s.pos < s.text.len {
		c := s.text[s.pos]
		if (c >= `0` && c <= `9`) || c == `_` {
			s.pos++
			continue
		}
		// fracton
		else if !has_decimal && c == `.` {
			has_decimal = true
			s.pos++
			continue
		}
		// exponent
		else if !has_exponent && c in [`e`, `E`] {
			has_exponent = true
			s.pos++
			continue
		}
		break
	}
}

[inline]
fn (mut s Scanner) name() {
	for s.pos < s.text.len {
		c := s.text[s.pos]
		if (c >= `0` && c <= `9`) || (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `_` {
			s.pos++
			continue
		}
		break
	}
}
