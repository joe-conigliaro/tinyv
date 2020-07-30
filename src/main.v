module main

import os
import os.cmdline
import tinyv.pref
import tinyv.builder

const(
	pref = &pref.Preferences{
		// debug: true
		// verbose: true
	}
)

fn main() {
	files := cmdline.only_non_options(os.args[1..])
	if files.len == 0 { eprintln('At least 1 .v file expected') exit(1) }
	$if debug { eprintln('v files: $files') }
	mut b := builder.new_builder(pref)
	b.build(files)
}
