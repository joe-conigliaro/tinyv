// Copyright (c) 2020-2023 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module builder

import tinyv.ast
import tinyv.gen.v as gen_v
import tinyv.pref
import tinyv.types
import time

struct Builder {
	pref &pref.Preferences
mut:
	files []ast.File
}

pub fn new_builder(prefs &pref.Preferences) &Builder {
	unsafe { return &Builder{
		pref: prefs
	} }
}

pub fn (mut b Builder) build(files []string) {
	mut sw := time.new_stopwatch()
	if b.pref.no_parallel {
		b.files = b.parse_files(files)
	} else {
		b.files = b.parse_files_async(files)
	}
	parse_time := sw.elapsed()
	// b.check_files()
	b.gen_v_files()
	gen_v_time := time.Duration(sw.elapsed() - parse_time)
	total_time := sw.elapsed()
	println(' * Scan & Parse: ${parse_time.milliseconds()}ms (${parse_time.microseconds()}us)')
	println(' * Gen (v): ${gen_v_time.milliseconds()}ms (${gen_v_time.microseconds()}us)')
	println(' * Total: ${total_time.milliseconds()}ms (${total_time.microseconds()}us)')
}

fn (mut b Builder) check_files() {
	checker := types.new_checker()
	checker.check_files(b.files)
}

fn (mut b Builder) gen_v_files() {
	mut gen := gen_v.new_gen(b.pref)
	for file in b.files {
		gen.gen(file)
		if b.pref.debug {
			gen.print_output()
		}
	}
}

// old - time scammer alone
// fn scan_files() {
// 	for file in files {
// 		mut text := os.read_file('$file') or {
// 			panic('error reading $file')
// 		}
// 		s := scanner.new_scanner(pref)
// 		s.set_text(text)
// 		t0 := time.ticks()
// 		for {
// 			kind := s.scan()
// 			// kind, lit, pos := s.scan()
// 			// println('lit: $s.lit - $kind - ' + int(kind).str())
// 			if kind == .eof {
// 				break
// 			}
// 		}
// 		// s.scan_all()
// 		t1 := time.ticks()
// 		scan_time := t1 - t0
// 		println('scan time for $file: ${scan_time}ms')
// 	}
// }
