// Copyright (c) 2020-2021 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module main

import os
import os.cmdline
import tinyv.pref
import tinyv.builder

fn main() {
	mut pref := pref.new_preferences()
	// pref.debug = true
	pref.verbose = true

	files := cmdline.only_non_options(os.args[1..])
	if files.len == 0 { eprintln('At least 1 .v file expected') exit(1) }
	$if debug { eprintln('v files: $files') }
	mut b := builder.new_builder(pref)
	b.build(files)
}