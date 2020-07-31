module scanner

import tinyv.token
import tinyv.pref

pub struct Scanner {
	pref          &pref.Preferences
	scan_comments bool
mut:
	text          string
pub mut:
	line_offsets  []int
	offset        int
	pos           int
	lit           string
}

pub fn new_scanner(pref &pref.Preferences, scan_comments bool) &Scanner {
	return &Scanner{
		pref: pref
		scan_comments: scan_comments
		line_offsets: [0]
	}
}

pub fn (mut s Scanner) set_text(text string) {
	s.text = text
}

pub fn (mut s Scanner) reset() {
	s.text = ''
	s.line_offsets = [0]
	s.offset = 0
	s.pos = 0
	s.lit = ''
}

pub fn (mut s Scanner) scan() token.Token {
	start:
	s.whitespace()
	if s.offset == s.text.len {
		s.lit = ''
		return .eof
	}
	c := s.text[s.offset]
	s.pos = s.offset
	// comment OR `/=` OR `/`
	if c == `/` {
		c2 := s.text[s.offset+1]
		// comment
		if c2 in [`/`, `*`] {
			s.comment()
			if !s.scan_comments {
				goto start
			}
			s.lit = s.text[s.pos..s.offset]
			return .comment
		}
		// `/=`
		else if c2 == `=` {
			s.offset+=2
			return .div_assign
		}
		s.offset++
		// `/`
		return .div
	}
	// number
	else if c >= `0` && c <= `9` {
		s.number()
		s.lit = s.text[s.pos..s.offset]
		return .number
	}
	// name
	else if (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c in [`_`, `@`] {
		s.name()
		s.lit = s.text[s.pos..s.offset]
		tok := token.key_tokens[s.lit]
		if tok != .unknown {
			return tok
		}
		return .name
	}
	// string
	else if c in [`'`, `"`] {
		s.string_literal()
		s.lit = s.text[s.pos+1..s.offset-1]
		return .string
	}
	// byte (char) `a`
	else if c == `\`` {
		s.offset++
		// NOTE: if there is more than one char still scan it
		// we can error at a later stage. should we error now?
		for s.text[s.offset] != c {
			if s.text[s.offset] == `\\` {
				s.offset+=2
				continue
			}
			s.offset++
		}
		s.offset++
		s.lit = s.text[s.pos+1..s.offset-1]
		return .char
	}
	s.lit = ''
	s.offset++
	match c {
		`.` {
			if s.text[s.offset] == `.` {
				s.offset++
				if s.text[s.offset] == `.` {
					s.offset++
					return .ellipsis
				}
				return .dotdot
			}
			return .dot
		}
		`:` {
			if s.text[s.offset] == `=` {
				s.offset++
				return .decl_assign
			}
			return .colon
		}
		`!` {
			c2 := s.text[s.offset]
			if c2 == `=` {
				s.offset++
				return .ne
			}
			else if c2 == `i` {
				c3 := s.text[s.offset+1]
				if c3 == `n` {
					s.offset+=2
					return .not_in
				}
				else if c3 == `s` {
					s.offset+=2
					return .not_is
				}
			}
			return .not
		}
		`=` {
			c2 := s.text[s.offset]
			if c2 == `=` {
				s.offset++
				return .eq
			}
			else if c2 == `>` {
				s.offset++
				return .arrow
			}
			return .assign
		}
		`+` {
			c2 := s.text[s.offset]
			if c2 == `+` {
				s.offset++
				return .inc
			}
			else if c2 == `=` {
				s.offset++
				return .plus_assign
			}
			return .plus
		}
		`-` {
			c2 := s.text[s.offset]
			if c2 == `-` {
				s.offset++
				return .dec
			}
			else if c2 == `=` {
				s.offset++
				return .minus_assign
			}
			return .minus
		}
		`%` {
			if s.text[s.offset] == `=` {
				s.offset++
				return .mod_assign
			}
			return .mod
		}
		`*` {
			if s.text[s.offset] == `=` {
				s.offset++
				return .mul_assign
			}
			return .mul
		}
		`^` {
			if s.text[s.offset] == `=` {
				s.offset++
				return .xor_assign
			}
			return .xor
		}
		`&` {
			c2 := s.text[s.offset]
			if c2 == `&` {
				// so that we pass &&Type as two .amp instead of .and
				// but this requires there is a space. we could check
				// for capital or some other way, this is simplest for now.
				if s.offset+2 <= s.text.len && s.text[s.offset+2] in [` `, `\t`] {
					s.offset++
					return .and
				}
			}
			else if c2 == `=` {
				s.offset++
				return .and_assign
			}
			return .amp
		}
		`|` {
			c2 := s.text[s.offset]
			if c2 == `|` {
				s.offset++
				return .logical_or
			}
			else if c2 == `=` {
				s.offset++
				return .or_assign
			}
			return .pipe
		}
		`<` {
			c2 := s.text[s.offset]
			if c2 == `<` {
				s.offset++
				if s.text[s.offset] == `=` {
					s.offset++
					return .left_shift_assign
				}
				return .left_shift
			}
			else if c2 == `=` {
				s.offset++
				return .le
			}
			return .lt
		}
		`>` {
			c2 := s.text[s.offset]
			if c2 == `>` {
				s.offset++
				if s.text[s.offset] == `=` {
					s.offset++
					return .right_shift_assign
				}
				return .right_shift
			}
			else if c2 == `=` {
				s.offset++
				return .ge
			}
			return .gt
		}
		`#` {
			// if we choose to scan whole line
			// s.line()
			return .hash
		}
		// `@` { return .at }
		// `#` { return .hash }
		`~` { return .bit_not }
		`,` { return .comma }
		`$` { return .dollar }
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
	for s.offset < s.text.len {
		c := s.text[s.offset]
		if c in [` `, `\t`] {
			s.offset++
			continue
		}
		else if c == `\n` {
			s.offset++
			s.line_offsets << s.offset
			continue
		}
		else if c == `\r` && s.text[s.offset+1] == `\n` {
			s.offset+=2
			s.line_offsets << s.offset
			continue
		}
		break
	}
}

fn (mut s Scanner) line() {
	// a newline reached here will get recorded by next whitespace call
	// we could add them manually here, but whitepace is called anyway
	for s.offset < s.text.len {
		c := s.text[s.offset]
		if c == `\n` {
			break
		}
		else if c == `\r` && s.text[s.offset+1] == `\n` {
			break
		}
		s.offset++
	}
}

fn(mut s Scanner) comment() {
	s.offset++
	match s.text[s.offset] {
		// single line
		`/` {
			s.line()
		}
		// multi line
		`*` {
			mut ml_comment_depth := 1
			for s.offset < s.text.len {
				c := s.text[s.offset]
				c2 := s.text[s.offset+1]
				if c == `\r` && c2 == `\n` {
					s.offset+=2
					s.line_offsets << s.offset
				}
				else if c == `\n` {
					s.offset++
					s.line_offsets << s.offset
				}
				else if c == `/` && c2 == `*` {
					s.offset+=2
					ml_comment_depth++
				}
				else if c == `*` && c2 == `/` {
					s.offset+=2
					ml_comment_depth--
					if ml_comment_depth == 0 {
						break
					}
				}
				else {
					s.offset++
				}
			}
		}
		else {}
	}
}

fn (mut s Scanner) string_literal() {
	c := s.text[s.offset]
	s.offset++
	for s.offset < s.text.len {
		c2 := s.text[s.offset]
		// skip escape \n | \'
		if c2 == `\\` {
			s.offset+=2
			continue
		}
		else if c2 == `\n` {
			s.offset++
			s.line_offsets << s.offset
			continue
		}
		else if c2 == `\r` && s.text[s.offset+1] == `\n` {
			s.offset+=2
			s.line_offsets << s.offset
			continue
		}
		// TODO: will probably store replacement positions in scanner
		// to save work by doing it later in parser, I still dont
		// think I want to break strings apart in scanner though
		// else if c2 == `$` {}
		else if c2 == c {
			s.offset++
			break
		}
		s.offset++
	}
}

fn (mut s Scanner) number() {
	if s.text[s.offset] == `0` {
		s.offset++
		c := s.text[s.offset]
		// TODO: fix underscore support
		// 0b (binary)
		if c in [`b`, `B`] {
			s.offset++
			for s.text[s.offset] in [`0`, `1`] {
				s.offset++
			}
			return
		}
		// 0x (hex)
		else if c in [`x`, `X`] {
			s.offset++
			for {
				c2 := s.text[s.offset]
				if (c2 >= `0` && c2 <= `9`) || (c2 >= `a` && c2 <= `z`) || (c2 >= `A` && c2 <= `Z`) || c2 == `_` {
					s.offset++
					continue
				}
				return
			}
		}
		// 0o (octal)
		else if c in [`o`, `O`] {
			s.offset++
			for {
				c2 := s.text[s.offset]
				if c2 >= `0` && c2 <= `7` {
					s.offset++
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
	for s.offset < s.text.len {
		c := s.text[s.offset]
		if (c >= `0` && c <= `9`) || c == `_` {
			s.offset++
			continue
		}
		// fracton
		else if !has_decimal && c == `.` {
			has_decimal = true
			s.offset++
			continue
		}
		// exponent
		else if !has_exponent && c in [`e`, `E`] {
			has_exponent = true
			s.offset++
			continue
		}
		break
	}
}

fn (mut s Scanner) name() {
	s.offset++
	for s.offset < s.text.len {
		c := s.text[s.offset]
		if  (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || (c >= `0` && c <= `9`) || c == `_` {
			s.offset++
			continue
		}
		break
	}
}

// TODO: move this somewhere maybe as a helper to ast file
// returns line_nr, col when passed pos
pub fn (s &Scanner) position(pos int) (int, int) {
	mut min, mut max := 0, s.line_offsets.len
	for min < max {
		mid := min + (max-min)/2
		// println('# min: $min, mid: $mid, max: $max')
		if s.line_offsets[mid] <= pos {
			min = mid + 1
		} else {
			max = mid
		}
	}
	return min, pos-s.line_offsets[min-1]+1
}
