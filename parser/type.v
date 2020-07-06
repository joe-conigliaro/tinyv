module parser

import types

// TODO:
pub fn (mut p Parser) parse_type() types.Type {
	// optional
	is_optional := p.tok == .question
	if is_optional {
		p.next()
	}
	// pointer
	mut ptr_count := 0
	for p.tok == .amp {
		p.next()
		ptr_count++
	}
	// map
	if p.tok == .name && p.scanner.lit == 'map' {
		p.next()
		p.expect(.lsbr)
		key_type := p.parse_type()
		p.expect(.rsbr)
		val_type := p.parse_type()
		return types.Type{}
	}
	// array
	else if p.tok == .lsbr {
		p.next()
		if p.tok == .number {
			p.next()
		}
		p.expect(.rsbr)
		elem_type := p.parse_type()
		return types.Type{}
	}
	// Tuple (multi return)
	else if p.tok == .lpar {
		p.next()
		mut mr_types := []types.Type{}
		for p.tok != .rpar {
			mr_types << p.parse_type()
			if p.tok == .comma {
				p.next()
			}
		}
		p.expect(.rpar)
		return types.Type{}
	}
	else if p.tok == .key_fn {
		return p.parse_fn_type()
	}

	typ := p.name()

	return types.Type{}
}


pub fn (mut p Parser) parse_fn_type() types.Type {
	p.next()
	if p.tok == .lpar {
		p.fn_args()
	}
	if p.tok in [.amp, .lsbr, .name, .question] {
		// return type
		p.parse_type()
	}
	return types.Type{}
}
