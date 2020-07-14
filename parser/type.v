module parser

import types

// TODO:
pub fn (mut p Parser) typ() types.Type {
	// optional
	is_optional := p.tok == .question
	if is_optional {
		p.next()
	}
	// pointer
	mut ptr_count := 0
	for p.tok in [.amp, .and] {
		if p.tok == .amp {
			ptr_count++
		}
		else {
			ptr_count+=2
		}
		p.next()
	}
	// map
	if p.tok == .name && p.scanner.lit == 'map' {
		p.next()
		p.expect(.lsbr)
		key_type := p.typ()
		p.expect(.rsbr)
		val_type := p.typ()
		return types.Type{}
	}
	// array
	else if p.tok == .lsbr {
		p.next()
		if p.tok == .number {
			p.next()
		}
		p.expect(.rsbr)
		elem_type := p.typ()
		return types.Type{}
	}
	// Tuple (multi return)
	else if p.tok == .lpar {
		p.next()
		mut mr_types := []types.Type{}
		for p.tok != .rpar {
			mr_types << p.typ()
			if p.tok == .comma {
				p.next()
			}
		}
		p.expect(.rpar)
		return types.Type{}
	}
	// variadic
	else if p.tok == .ellipsis {
		p.next()
		p.typ()
		return types.Type{}
	}
	else if p.tok == .key_fn {
		return p.parse_fn_type()
	}
	mut name := ''
	for p.tok == .name {
		name = p.name()
		if p.tok == .dot {
			name += '.'
			p.next()
		}
		break
	}

	return types.Type{}
}


pub fn (mut p Parser) parse_fn_type() types.Type {
	p.next()
	if p.tok == .lpar {
		p.fn_args()
	}
	if p.tok in [.amp, .lsbr, .name, .question] {
		// return type
		p.typ()
	}
	return types.Type{}
}
