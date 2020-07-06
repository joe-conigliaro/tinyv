module main

import os
import time
import scanner
import parser

// import v.scanner as vscanner

fn main() {
	// text := 'a := 1*2'
	// text := 'for i,x in chars { println(a)\nx := 100\n g++\ny := @ }'

	// file := '/home/kastro/dev/src/v/vlib/builtin/string.v'
	// file := '/home/kastro/dev/src/v/vlib/regex/regex.v'
	files := [
		//'/home/kastro/dev/src/hv/syntax.v'
		'/mnt/storage/homes/kastro/dev/v/vlib/builtin/int.v',
		'/mnt/storage/homes/kastro/dev/v/vlib/builtin/string.v',
		'/mnt/storage/homes/kastro/dev/v/vlib/regex/regex.v',
		'/mnt/storage/homes/kastro/dev/v/vlib/crypto/aes/block_generic.v'
	]
	total0 := time.ticks()
	for file in files {
		mut text := os.read_file(file) or {
			panic('error reading $file')
		}
		s := scanner.new_scanner(text)
		t0 := time.ticks()
		for {
			kind := s.scan()
			// kind, lit, pos := s.scan()
			// println('lit: $s.lit - $kind - ' + int(kind).str())
			if kind == .eof {
				break
			}
		}
		// s.scan_all()
		t1 := time.ticks()
		scan_time := t1 - t0
		println('scan time for $file: ${scan_time}ms')


		// vs := vscanner.new_scanner(text, .parse_comments)
		// tt0 := time.ticks()
		// for {
		// 	tok := vs.scan()
		// 	// println('lit: $tok.lit')
		// 	if tok.kind == .eof {
		// 		break
		// 	}
		// }
		// tt1 := time.ticks()
		// vscan_time := tt1 - tt0
		// println('vscan time: ${vscan_time}ms')

		pt0 := time.ticks()
		mut p := parser.new_parser(file)
		p.parse()
		pt1 := time.ticks()
		parse_time := pt1 - pt0
		println('parse time for $file: ${parse_time}ms')
	}
	total1 := time.ticks()
	total_time := total1 - total0
	println('total time: ${total_time}ms')
}
