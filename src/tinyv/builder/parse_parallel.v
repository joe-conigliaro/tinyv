// Copyright (c) 2020-2023 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module builder

import tinyv.ast
import tinyv.pref
import tinyv.parser
import runtime

// TODO: remove workaround once fixed in compiler
struct SharedIntWorkaround { mut: value int }
struct ParsingSharedState {
mut:
	parsed_modules      shared []string
	queued_files_length shared SharedIntWorkaround
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

fn (mut pstate ParsingSharedState) queue_files(ch_in chan string, files []string) {
	for file in files {
		// eprintln('>>>> ${@METHOD} file: $file')
		ch_in <- file
		lock pstate.queued_files_length {
			pstate.queued_files_length.value++
		}
	}
}

fn (mut pstate ParsingSharedState) worker(prefs &pref.Preferences, ch_in chan string, ch_out chan ast.File) {
	// eprintln('>> ${@METHOD}')
	mut p := parser.new_parser(prefs)
	for {
		filename := <- ch_in or { break }
		ast_file := p.parse_file(filename)		
		if !prefs.skip_imports {
			for mod in ast_file.imports {
				if pstate.already_parsed_module( mod.name ) {
					continue
				}
				pstate.mark_module_as_parsed(mod.name)
				mod_path := prefs.get_module_path(mod.name, ast_file.name)
				pstate.queue_files(ch_in, get_v_files_from_dir(mod_path))
			}
		}
		// eprintln('>> ${@METHOD} fully parsed file: $filename')
		lock pstate.queued_files_length {
			pstate.queued_files_length.value--
		}
		ch_out <- ast_file
	}
}

fn (mut b Builder) parse_files_parallel(files []string) []ast.File {
	mut ch_in := chan string{cap: 1000}
	mut ch_out := chan ast.File{cap: 1000}
	mut pstate := &ParsingSharedState{}
	mut ast_files := []ast.File{}
	mut threads := []thread{}
	
	// spawn workers
	for _ in 0..runtime.nr_jobs() {
		// dump(thread_idx)
		threads << spawn pstate.worker(b.pref, ch_in, ch_out)
	}
	// parse builtin
	if !b.pref.skip_builtin {
		pstate.queue_files(ch_in, get_v_files_from_dir(b.pref.get_vlib_module_path('builtin')))
	}
	// parse user files
	pstate.queue_files(ch_in, files)

	// mut output_idx := 0
	for {
		// output_idx++
		rlock pstate.queued_files_length {
			if pstate.queued_files_length.value == 0 {
				// eprintln('output reading idx: $output_idx')
				// dump(pstate)
				break
			}
		}
		ast_file := <- ch_out
		ast_files << ast_file
	}
	
	ch_in.close()
	ch_out.close()
	threads.wait()       

	return ast_files
}