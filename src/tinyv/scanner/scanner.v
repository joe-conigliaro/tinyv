// Copyright (c) 2020-2023 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module scanner

import tinyv.token
import tinyv.pref

type EmptyInfo = u8
type Info = EmptyInfo | StringLiteralInfo
const empty_info = Info(EmptyInfo(0))

struct StringLiteralInfo {
pub:
	kind token.StringLiteralKind
	quote u8
}

pub fn (i Info) string_literal() StringLiteralInfo {
	return i as StringLiteralInfo
}

pub struct Scanner {
	pref          &pref.Preferences
	scan_comments bool
mut:
	file   &token.File = &token.File{}
	src    string
pub mut:
	offset int // current char offset
	pos    int // token offset (start of current token)
	lit    string
	info   Info
}

pub fn new_scanner(prefs &pref.Preferences, scan_comments bool) &Scanner {
	unsafe { return &Scanner{
		pref: prefs
		scan_comments: scan_comments
	} }
}

pub fn (mut s Scanner) init(file &token.File, src string) {
	// reset since scanner instance may be reused
	s.offset = 0
	s.pos = 0
	s.lit = ''
	// init
	s.file = unsafe { file }
	s.src = src
	s.info = empty_info
}

[direct_array_access]
pub fn (mut s Scanner) scan() token.Token {
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
			if !s.scan_comments {
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
		// `c'c string"` | `r'raw string'`
		if s.src[s.offset] in [`'`, `"`] {
			// TODO: maybe move & need to make use of these
			string_lit_kind := if c == `c` { token.StringLiteralKind.c } 
				else if c == `r` { token.StringLiteralKind.raw }
				else { panic('unknown string prefix `$c`') /* :) */ token.StringLiteralKind.v }
			c_quote := s.src[s.offset]
			// TODO: need a way to use the correct quote when string includes quotes
			// best done before gen so it wont need to worry about it (prob parser)
			s.string_literal(string_lit_kind)
			s.lit = s.src[s.pos+2..s.offset-1]
			// NOTE: i'm not sure if this is useful enough to keep, it saves
			// re checkin information in parser we have alrerady checked here
			// however it might be better just to do it the normal way and
			// remove this all together! just an idea.
			s.info = StringLiteralInfo{kind: string_lit_kind, quote: c_quote}
			return .string
		}
		// keyword | name
		for s.offset < s.src.len {
			c2 := s.src[s.offset]
			if  (c2 >= `a` && c2 <= `z`) || (c2 >= `A` && c2 <= `Z`) || (c2 >= `0` && c2 <= `9`) || c2 == `_` {
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
		s.string_literal(.v)
		s.lit = s.src[s.pos+1..s.offset-1]
		s.info = StringLiteralInfo{kind: .v, quote: c}
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
			if s.src[s.offset] == `.` {
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
fn (mut s Scanner) string_literal(kind token.StringLiteralKind) {
	c_quote := s.src[s.offset]
	s.offset++
	// shortcut raw strings
	if kind == .raw {
		for s.src[s.offset] != c_quote && s.offset < s.src.len {
			s.offset++
		}
		s.offset++
		return
	}
	// everything else
	mut in_interpolation := false
	for s.offset < s.src.len {
		c2 := s.src[s.offset]
		c3 := s.src[s.offset+1]
		// skip escape \n | \'
		if c2 == `\\` && kind != .raw {
		// if c2 == `\\` {
			s.offset+=2
			continue
		}
		else if c2 == `\n` && kind != .raw {
		// else if c2 == `\n` {
			s.offset++
			s.file.add_line(s.offset)
			continue
		}
		else if c2 == `$` && c3 == `{` {
			in_interpolation = true
		}
		else if c2 == `}` && in_interpolation {
			in_interpolation = false
		}
		// TODO: I will probably store replacement positions in scanner
		// for efficiency rather than doing it later in parser, I still
		// don't think I want to break strings apart in scanner though
		// else if c2 == `$` {}
		// Actually, with the v style interpolation this won't be possible.
		// I will just break them apart so I can parse exprs in parser.
		// TODO: since support for non escaped quotes inside ${} was added
		// i will need to do some checking here
		else if c2 == c_quote && !in_interpolation {
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
