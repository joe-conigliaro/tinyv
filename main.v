module main

import os
import time
import scanner
import parser
// import v.scanner as vscanner

const(
	v_dir = '/home/kastro/dev/src/v'
	// v_dir = '/mnt/storage/homes/kastro/dev/v'
	files = [
		'vlib/builtin/int.v',
		'vlib/builtin/string.v',
		'vlib/regex/regex.v',
		'vlib/crypto/aes/block_generic.v'
	]
)

fn main() {
	total0 := time.ticks()
	parse_files()
	total1 := time.ticks()
	total_time := total1 - total0
	println('total time: ${total_time}ms')
}

pub fn scan_files() {
	for file in files {
		mut text := os.read_file('$v_dir/$file') or {
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
	}
}

// pub fn scan_files_v2() {
// 	for file in files {
// 		mut text := os.read_file('$v_dir/$file') or {
// 			panic('error reading $file')
// 		}
// 		vs := vscanner.new_scanner(text, .parse_comments)
// 		tt0 := time.ticks()
// 		for {
// 			tok := vs.scan()
// 			// println('lit: $tok.lit')
// 			if tok.kind == .eof {
// 				break
// 			}
// 		}
// 		tt1 := time.ticks()
// 		vscan_time := tt1 - tt0
// 		println('vscan time: ${vscan_time}ms')
// 	}
// }

pub fn parse_files() {
	for file in files {
		pt0 := time.ticks()
		mut p := parser.new_parser('$v_dir/$file')
		p.parse()
		pt1 := time.ticks()
		parse_time := pt1 - pt0
		println('scan & parse time for $file: ${parse_time}ms')
	}
}
