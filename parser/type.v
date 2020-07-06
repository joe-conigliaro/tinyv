module parser

import types

// TODO:
pub fn (mut p Parser) parse_type() types.Type {
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
	if p.tok == .lsbr {
		p.next()
		if p.tok == .number {
			p.next()
		}
		p.expect(.rsbr)
		elem_type := p.parse_type()
		return types.Type{}
	}

	typ := p.scanner.lit
	p.expect(.name)

	return types.Type{}
}
