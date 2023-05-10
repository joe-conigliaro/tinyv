// Copyright (c) 2020-2023 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module scanner

import tinyv.token
import tinyv.pref

[flag]
pub enum Mode {
	scan_comments
	skip_interpolation
}

pub struct Scanner {
	pref   &pref.Preferences
	mode   Mode
	skip_interpolation bool
mut:
	file   &token.File = &token.File{}
	src    string
pub mut:
	offset int // current char offset
	pos    int // token offset (start of current token)
	lit    string
	// strings literals & interpolation
	in_str_incomplete   bool
	in_str_inter        bool
	str_inter_cbr_depth int
	str_quote u8
}

pub fn new_scanner(prefs &pref.Preferences, mode Mode) &Scanner {
	unsafe { return &Scanner{
		pref: prefs
		mode: mode
		skip_interpolation: mode.has(.skip_interpolation)
	} }
}

pub fn (mut s Scanner) init(file &token.File, src string) {
	// reset since scanner instance may be reused
	s.offset = 0
	s.pos = 0
	s.lit = ''
	// s.in_str_incomplete = false
	// s.in_str_inter = false
	// s.str_inter_cbr_depth = 0
	// init
	s.file = unsafe { file }
	s.src = src
}

[direct_array_access]
pub fn (mut s Scanner) scan() token.Token {
	// before whitespace call to keep whitepsaces in string
	// NOTE: before start: simply for a little more efficiency
	// if !s.skip_interpolation && s.in_str_incomplete {
	if s.in_str_incomplete {
		s.in_str_incomplete = false
		s.pos = s.offset
		s.string_literal(false, s.str_quote)
		s.lit = s.src[s.pos..s.offset]
		return .string
	}
	start:
	s.whitespace()
	if s.offset == s.src.len {
		s.lit = ''
		s.file.add_line(s.offset)
		return .eof
	}
	c := s.src[s.offset]
	s.pos = s.offset
	// comment | `/=` | `/`
	if c == `/` {
		c2 := s.src[s.offset+1]
		// comment
		if c2 in [`/`, `*`] {
			s.comment()
			if !s.mode.has(.scan_comments) {
				unsafe { goto start }
			}
			s.lit = s.src[s.pos..s.offset]
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
		s.lit = s.src[s.pos..s.offset]
		return .number
	}
	// c/raw string | keyword | name
	else if (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c in [`_`, `@`] {
		s.offset++
		// keyword | name
		for s.offset < s.src.len {
			c3 := s.src[s.offset]
			if  (c3 >= `a` && c3 <= `z`) || (c3 >= `A` && c3 <= `Z`) || (c3 >= `0` && c3 <= `9`) || c3 == `_` {
				s.offset++
				continue
			}
			break
		}
		s.lit = s.src[s.pos..s.offset]
		tok := token.keyword_to_token(s.lit)
		if tok != .unknown {
			return tok
		}
		return .name
	}
	// string
	else if c in [`'`, `"`] {
		s.offset++
		if !s.in_str_inter {
			s.str_quote = c
		}
		// TODO: I would prefer a better way to handle raw
		s.string_literal(s.in_str_inter || s.src[s.offset-2] == `r`, c)
		s.lit = s.src[s.pos..s.offset]
		return .string
	}
	// byte (char) `a`
	else if c == `\`` {
		s.offset++
		// NOTE: if there is more than one char still scan it
		// we can error at a later stage. should we error now?
		for {
			c2 := s.src[s.offset]
			if c2 == c { break }
			else if c2 == `\\` {
				s.offset+=2
				continue
			}
			s.offset++
		}
		s.offset++
		s.lit = s.src[s.pos+1..s.offset-1]
		return .char
	}
	// s.lit not set, as tokens below get converted directly to string
	s.lit = ''
	s.offset++
	match c {
		`.` {
			c2 := s.src[s.offset]
			if c2 >= `0` && c2 <= `9` {
				// TODO: only really need decimal
				s.number()
				s.lit = s.src[s.pos..s.offset]
				return .number
			}
			else if c2 == `.` {
				s.offset++
				if s.src[s.offset] == `.` {
					s.offset++
					return .ellipsis
				}
				return .dotdot
			}
			return .dot
		}
		`:` {
			if s.src[s.offset] == `=` {
				s.offset++
				return .decl_assign
			}
			return .colon
		}
		`!` {
			c2 := s.src[s.offset]
			if c2 == `=` {
				s.offset++
				return .ne
			}
			else if c2 == `i` {
				c3 := s.src[s.offset+1]
				c4_is_space := s.src[s.offset+2] in [` `, `\t`]
				if c3 == `n` && c4_is_space {
					s.offset+=2
					return .not_in
				}
				else if c3 == `s` && c4_is_space {
					s.offset+=2
					return .not_is
				}
			}
			return .not
		}
		`=` {
			c2 := s.src[s.offset]
			if c2 == `=` {
				s.offset++
				return .eq
			}
			return .assign
		}
		`+` {
			c2 := s.src[s.offset]
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
			c2 := s.src[s.offset]
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
			if s.src[s.offset] == `=` {
				s.offset++
				return .mod_assign
			}
			return .mod
		}
		`*` {
			if s.src[s.offset] == `=` {
				s.offset++
				return .mul_assign
			}
			return .mul
		}
		`^` {
			if s.src[s.offset] == `=` {
				s.offset++
				return .xor_assign
			}
			return .xor
		}
		`&` {
			c2 := s.src[s.offset]
			if c2 == `&` {
				// so that we parse &&Type as two .amp instead of .and
				// but this requires there is a space. we could check
				// for capital or some other way, this is simplest for now.
				if s.offset+1 <= s.src.len && s.src[s.offset+1] in [` `, `\t`] {
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
			c2 := s.src[s.offset]
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
			c2 := s.src[s.offset]
			if c2 == `<` {
				s.offset++
				if s.src[s.offset] == `=` {
					s.offset++
					return .left_shift_assign
				}
				return .left_shift
			}
			else if c2 == `=` {
				s.offset++
				return .le
			}
			else if c2 == `-` {
				s.offset++
				return .arrow
			}
			return .lt
		}
		`>` {
			c2 := s.src[s.offset]
			if c2 == `>` {
				s.offset++
				c3 := s.src[s.offset]
				if c3 == `>` {
					s.offset++
					if s.src[s.offset] == `=` {
						s.offset++
						return .right_shift_unsigned_assign
					}
					return .right_shift_unsigned
				}
				else if c3 == `=` {
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
		`~` { return .bit_not }
		`,` { return .comma }
		`$` {
			if s.in_str_inter {
				return .str_dollar
			}
			return .dollar
		}
		`{` {
			if s.in_str_inter {
				s.str_inter_cbr_depth++
			}
			return .lcbr
		}
		`}` {
			if s.in_str_inter {
				s.str_inter_cbr_depth--
				if s.str_inter_cbr_depth == 0 {
					s.in_str_incomplete = true
					s.in_str_inter = false
				}
			}
			return .rcbr
		}
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
[direct_array_access]
fn (mut s Scanner) whitespace() {
	for s.offset < s.src.len {
		c := s.src[s.offset]
		if c in [` `, `\t`, `\r`] {
			s.offset++
			continue
		} else if c == `\n` {
			s.offset++
			s.file.add_line(s.offset)
			continue
		}
		break
	}
}

[direct_array_access]
fn (mut s Scanner) line() {
	// a newline reached here will get recorded by next whitespace call
	// we could add them manually here, but whitespace is called anyway
	for s.offset < s.src.len {
		if s.src[s.offset] == `\n` {
			break
		}
		s.offset++
	}
}

[direct_array_access]
fn (mut s Scanner) comment() {
	s.offset++
	c := s.src[s.offset]
	// single line
	if c == `/` {
		s.line()
	}
	// multi line
	else if c == `*` {
		mut ml_comment_depth := 1
		for s.offset < s.src.len {
			c2 := s.src[s.offset]
			c3 := s.src[s.offset+1]
			if c2 == `\n` {
				s.offset++
				s.file.add_line(s.offset)
			}
			else if c2 == `/` && c3 == `*` {
				s.offset+=2
				ml_comment_depth++
			}
			else if c2 == `*` && c3 == `/` {
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
}

[direct_array_access]
fn (mut s Scanner) string_literal(scan_as_raw bool, c_quote u8) {
	// shortcut, scan whole string
	if scan_as_raw {
		for s.offset < s.src.len && s.src[s.offset] != c_quote {
			s.offset++
		}
		s.offset++
		return
	}
	// normal strings
	for s.offset < s.src.len {
		c := s.src[s.offset]
		// escape `\\n` | `\'`
		if c == `\\` {
			s.offset+=2
			continue
		}
		else if c == `\n` {
			s.offset++
			s.file.add_line(s.offset)
			continue
		}
		else if c == `$` && s.src[s.offset+1] == `{` {
			s.in_str_inter = true
			if s.skip_interpolation {
				s.str_inter_cbr_depth++
				s.offset+=2
				continue
			} else {
				return
			}
		}
		else if s.skip_interpolation && s.in_str_inter {
			if c == `{` {
				s.str_inter_cbr_depth++
			} else if c == `}` {
				s.str_inter_cbr_depth--
				if s.str_inter_cbr_depth == 0 {
					s.in_str_inter = false
				}
			}
		}
		else if c == c_quote && !s.in_str_inter {
			s.offset++
			break
		}
		s.offset++
	}
}

[direct_array_access]
fn (mut s Scanner) number() {
	if s.src[s.offset] == `0` {
		s.offset++
		c := s.src[s.offset]
		// TODO: impl proper underscore support
		// 0b (binary)
		if c in [`b`, `B`] {
			s.offset++
			for s.src[s.offset] in [`0`, `1`] {
				s.offset++
			}
			return
		}
		// 0x (hex)
		else if c in [`x`, `X`] {
			s.offset++
			for {
				c2 := s.src[s.offset]
				if (c2 >= `0` && c2 <= `9`) || (c2 >= `a` && c2 <= `f`)
					|| (c2 >= `A` && c2 <= `F`) || c2 == `_` {
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
				c2 := s.src[s.offset]
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
	// TODO: proper impl of fraction / exponent
	// continue decimal (and also completion of bin/octal)
	for s.offset < s.src.len {
		c := s.src[s.offset]
		if (c >= `0` && c <= `9`) || c == `_` {
			s.offset++
			continue
		}
		// fraction
		else if !has_decimal && c == `.` && s.src[s.offset+1] != `.` /* range */ {
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

// TODO: move to appropriate place
pub fn (s &Scanner) error_details(pos token.Position, row_padding int) string {
	line_start := if pos.line-row_padding-1 > 0 {
		s.file.line_start(pos.line - row_padding)
	} else {
		0
	}
	mut line_end := pos.offset+1
	for i := 0; line_end<s.src.len; {
		if s.src[line_end] == `\n` {
			i++
			if i == row_padding+1 { break }
		}
		line_end++
	}
	lines_src := s.src[line_start..line_end].split('\n')
	line_no_start, _ := s.file.find_line_and_column(line_start)
	mut lines_formatted := []string{}
	for i in 0..lines_src.len {
		line_no := line_no_start+i
		line_src := lines_src[i]
		line_spaces := line_src.replace('\t', '    ')
		lines_formatted << '${line_no:5d} | ' + line_spaces
		if line_no == pos.line {
			space_diff := line_spaces.len - line_src.len
			lines_formatted << '        ' + ' '.repeat(space_diff+pos.column-1) + '^'
		}
	}
	return lines_formatted.join('\n')
}
