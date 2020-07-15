module main

import os
import os.cmdline
import pref
import builder

const(
	pref = &pref.Preferences{
		debug: false
		// debug: true
		// verbose: false
		verbose: false
	}
)

fn main() {
	files := cmdline.only_non_options(os.args[1..])
	if files.len == 0 { eprintln('At least 1 .v file expected') exit(1) }
	$if debug { eprintln('v files: $files') }
	b := builder.new_builder(pref)
	b.build(files)
}

