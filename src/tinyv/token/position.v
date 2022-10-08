// Copyright (c) 2020-2021 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module token

// TODO: fileset / file / base pos etc

pub struct Position {
	filename string
	offset	 int
	line     int
	column   int
}

pub fn (p Position) str() string {
	return '$p.filename:$p.line:$p.column'
}
