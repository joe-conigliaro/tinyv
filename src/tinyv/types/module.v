// Copyright (c) 2020-2021 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module types

pub struct Module {
	name  string
	path  string
	scope &Scope
}

pub fn new_module(name string, path string, parent &Scope) Module {
	return Module{
		name: name
		path: path
		scope: new_scope(parent)
	}
}
