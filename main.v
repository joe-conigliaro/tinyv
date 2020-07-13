module main

import os
import time
import scanner
import parser
import ast
import pref
import gen.v as gen_v
// import v.scanner as vscanner

const(
	// v_dir = '/home/kastro/dev/src/v'
	v_dir = '/mnt/storage/homes/kastro/dev/v'
	files = [
		'$v_dir/vlib/builtin/int.v',
		'$v_dir/vlib/builtin/string.v',
		'$v_dir/vlib/regex/regex.v',
		'$v_dir/vlib/crypto/aes/block_generic.v'
		'tests/syntax.v'
	]
	prefs = &pref.Preferences{
		verbose: false
	}
)

fn main() {
	total0 := time.ticks()
	ast_files := parse_files()
	vgen_files(ast_files)
	total1 := time.ticks()
	total_time := total1 - total0
	println('total time: ${total_time}ms')
}

fn scan_files() {
	for file in files {
		mut text := os.read_file('$file') or {
			panic('error reading $file')
		}
		s := scanner.new_scanner(prefs)
		s.set_text(text)
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
// 		mut text := os.read_file('$file') or {
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

fn parse_files() []ast.File {
	mut ast_files := []ast.File{}
	mut p := parser.new_parser(prefs)
	for file in files {
		pt0 := time.ticks()
		ast_files << p.parse(file)
		pt1 := time.ticks()
		parse_time := pt1 - pt0
		println('scan & parse time for $file: ${parse_time}ms')
	}
	return ast_files
}

fn vgen_files(ast_files []ast.File) {
	mut gen := gen_v.new_gen(prefs)
	for file in ast_files {
		gt0 := time.ticks()
		gen.gen(file)
		gt1 := time.ticks()
		gen_time := gt1-gt0
		println('v gen for $file.path: ${gen_time}ms')
	}
}
