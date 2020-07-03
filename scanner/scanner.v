module scanner

import token

pub struct Scanner {
	text   string
// mut:
	// tokens []token.Token
pub mut:
	last_nl_pos int
	line_nr int
	pos     int
	lit     string
}

pub fn new_scanner(text string) &Scanner {
	return &Scanner{
		line_nr: 1
		text: text
		// tokens: tokens
	}
}

// NOTE: scan/scan0 was split in case i choose to cache all tokens / peek
pub fn (mut s Scanner) scan() token.Token {
	s.whitespace()
	start_pos := s.pos
	tok := s.scan0()
	// s.tokens << token.Token{
	// 	kind: tok,
	// 	lit: s.lit,
	// 	line_nr: s.line_nr
	// 	pos: start_pos
	// }
	return tok
}

pub fn (mut s Scanner) scan0() token.Token {
	// s.whitespace()
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
	// comments
	if c == `/` {
		s.comment()
		s.lit = s.text[start_pos..s.pos]
		return .comment
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
		s.lit = s.text[start_pos..s.pos]
		return .string
	}
	// byte (char) `a`
	else if c == `\`` {
		s.pos++
		for s.text[s.pos] != c {
			s.pos++
		}
		s.pos++
		// s.lit = c.str()
		s.lit = s.text[start_pos..s.pos]
		return .chartoken
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
			if s.text[s.pos] == `=` {
				s.pos++
				return .ne
			}
			else if s.text[s.pos..s.pos+2] == 'in' {
				s.pos+=2
				return .not_in
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
				return .mult_assign
			}
			return .mul
		}
		`/` {
			if s.text[s.pos] == `=` {
				s.pos++
				return .div_assign
			}
			return .div
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
		`#` { return .hash }
		`,` { return .comma }
		// `@` { return .at }
		`;` { return .semicolon }
		`{` { return .lcbr }
		`}` { return .rcbr }
		`(` { return .lpar }
		`)` { return .rpar }
		`[` { return .lsbr }
		`]` { return .rsbr }
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
			for s.pos < s.text.len {
				if s.text[s.pos] == `\r` && s.text[s.pos+1] == `\n` {
					s.last_nl_pos = s.pos
					s.line_nr++
					s.pos+=2
					continue
				}
				else if s.text[s.pos] == `\n` {
					s.last_nl_pos = s.pos
					s.line_nr++
					s.pos++
					continue
				}
				if s.text[s.pos]== `*` && s.text[s.pos+1] == `/` {
					s.pos+=2
					break
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
		// skip escape \n | \'
		if s.text[s.pos] == `\\` {
			s.pos+=2
			continue
		}
		if s.text[s.pos] == c {
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
				if (c2 >= `0` && c2 <= `9`) || (c2 >= `a` && c2 <= `z`) || (c2 >= `A` && c2 <= `Z`) {
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
	// continue decimal (and also completion of bin/octal)
	for s.pos < s.text.len {
		c := s.text[s.pos]
		if c >= `0` && c <= `9` {
			s.pos++
			continue
		}
		break
	}
	// TODO: fraction & exponent
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
