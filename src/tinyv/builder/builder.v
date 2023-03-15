// Copyright (c) 2020-2021 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module builder

import os
import tinyv.ast
import tinyv.gen.v as gen_v
import tinyv.parser
import tinyv.pref
import tinyv.types
import time
import runtime

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
	b.files = b.parse_files(files)
	parse_time := sw.elapsed()
	// b.check_files()
	b.gen_v_files()
	gen_v_time := time.Duration(sw.elapsed() - parse_time)
	total_time := sw.elapsed()
	println(' * Scan & Parse: ${parse_time.milliseconds()}ms (${parse_time.microseconds()}us)')
	println(' * Gen (v): ${gen_v_time.milliseconds()}ms (${gen_v_time.microseconds()}us)')
	println(' * Total: ${total_time.milliseconds()}ms (${total_time.microseconds()}us)')
}

////////////
struct ParsingSharedState {
mut:
    parsed_modules shared []string
    files_to_be_parsed int
    files_already_parsed int
}
fn (mut pstate ParsingSharedState) mark_module_as_parsed( name string ) {
   lock pstate.parsed_modules {
       pstate.parsed_modules << name
   }
}
fn (mut pstate ParsingSharedState) already_parsed_module(name string) bool {
   rlock pstate.parsed_modules {
       if name in pstate.parsed_modules {
           return true
       }
   }
   return false
}
fn (mut pstate ParsingSharedState) parse_files_async(ch_in chan string, files []string) {
	for file in files {
	        eprintln('>>>> ${@METHOD} file: $file')
		ch_in <- file
		pstate.files_to_be_parsed++
	}
}
fn (mut pstate ParsingSharedState) parse_async_worker(mut b Builder, ch_in chan string, ch_out chan ast.File) {
        eprintln('>> ${@METHOD}')
	mut p := parser.new_parser(b.pref)
	for {
		filename := <- ch_in or { break }
                ast_file := p.parse_file(filename)		
	        for mod in ast_file.imports {
		        if pstate.already_parsed_module( mod.name ) {
			    continue
		        }
		 	pstate.mark_module_as_parsed(mod.name)
			
		 	mod_path := b.get_module_path(mod.name, ast_file.path)
		 	pstate.parse_files_async(ch_in, get_v_files_from_dir(mod_path))
		}
                // eprintln('>> ${@METHOD} fully parsed file: $filename')
		pstate.files_already_parsed++
		ch_out <- ast_file
    }
}
////////////
fn (mut b Builder) parse_files(files []string) []ast.File {
	mut ch_in := chan string{cap: 1000}
	mut ch_out := chan ast.File{cap: 1000}
	mut pstate := &ParsingSharedState{}
	mut ast_files := []ast.File{}
	mut threads := []thread{}
	for thread_idx in 0..runtime.nr_jobs() {
	        dump(thread_idx)
		threads << spawn pstate.parse_async_worker(mut b, ch_in, ch_out)
	}
	// parse builtin
	if !b.pref.skip_builtin {
		pstate.parse_files_async(ch_in, get_v_files_from_dir(b.get_vlib_module_path('builtin')))
	}
	// parse user files
	pstate.parse_files_async(ch_in, files)
	if b.pref.skip_imports {
		return ast_files
	}

	println(' 1 ast_file.len: $ast_files.len')
	mut output_idx := 0
	for {
	        output_idx++
		if pstate.files_already_parsed == pstate.files_to_be_parsed {
	           eprintln('output reading idx: $output_idx')
             	   dump(pstate)
		   break
	        }
		ast_file := <- ch_out
		ast_files << ast_file
	}
	
	ch_in.close()
	ch_out.close()
	threads.wait()       

	println(' 2 ast_file.len: $ast_files.len')
	return ast_files
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

fn (b &Builder) get_vlib_module_path(mod string) string {
	mod_path := mod.replace('.', os.path_separator)
	return os.join_path(b.pref.vroot, 'vlib', mod_path)
}

// check for relative and then vlib
fn (b &Builder) get_module_path(mod string, importing_file_path string) string {
	mod_path := mod.replace('.', os.path_separator)
	// TODO: is this the best order?
	// vlib
	vlib_path := os.join_path(b.pref.vroot, 'vlib', mod_path)
	if os.is_dir(vlib_path) {
		return vlib_path
	}
	// ~/.vmodules
	vmodules_path := os.join_path(b.pref.vmodules_path, mod_path)
	if os.is_dir(vmodules_path) {
		return vmodules_path
	}
	// relative to file importing it
	relative_path := os.join_path(os.dir(importing_file_path), mod_path)
	if os.is_dir(relative_path) {
		return relative_path
	}
	panic('get_module_path: cannot find module path for $mod')
}

fn get_v_files_from_dir(dir string) []string {
	mod_files := os.ls(dir)  or {
		panic('error getting ls from $dir')
	}
	mut v_files := []string{}
	for file in mod_files {
		if !file.ends_with('.v') || file.ends_with('.js.v') || file.ends_with('_test.v') {
			continue
		}
		v_files << os.join_path(dir, file)
	}
	return v_files
}

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
