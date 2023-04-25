// Copyright (c) 2020-2023 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module token

// TODO: finish fileset / file / base pos etc

// compact encoding of a source position within a file set
type CompactPosition = int

pub struct Position {
pub:
	filename string
	offset	 int
	line     int
	column   int
}

pub fn (p Position) str() string {
	return '$p.filename:$p.line:$p.column'
}

pub struct File {
pub:
	name     	 string
	base	     int
	size		 int
mut:
	line_offsets []int = [0] // start of each line
}

pub struct FileSet {
mut:
	base  int
	files shared []&File
}

// TODO:
pub fn (mut fs FileSet) add_file(filename string, base_ int, size int) &File {
	mut base := if base_ < 0 { fs.base } else { base_ }
	if base < fs.base {
		panic('invalid base $base (should be >= $fs.base')
	}
	file := &File{name: filename, base: base, size: size}
	if size < 0 {
		panic('invalid size $size (should be >= 0)')
	}
	base += size + 1 // +1 because EOF also has a position
	if base < 0 {
		panic('token.Pos offset overflow (> 2G of source code in file set)')
	}
	// add the file to the file set
	fs.base = base
	lock fs.files {
		fs.files << file
	}
	// fs.last = file
	return file
}

pub fn new_file(filename string) File {
	return File{
		name: filename
	}
}

[inline]
pub fn (mut f File) add_line(offset int) {
	f.line_offsets << offset
}

[inline]
pub fn (f &File) line_count() int {
	return f.line_offsets.len
}

pub fn (f &File) line_start(line int) int {
	return f.line_offsets[line-1] or {
		panic('invlid line `$line` (must be > 0 & < $f.line_count())')
	}
}

pub fn (f &File) line(pos CompactPosition) int {
	return f.find_line(pos)
}

pub fn (f &File) position(pos CompactPosition) Position {
	offset := int(pos) - f.base
	line, column := f.find_line_and_column(offset)
	return Position{
		filename: f.name
		offset: offset
		line: line
		column: column
	}
}

// return (line, column) when passed pos
pub fn (f &File) find_line_and_column(pos int) (int, int) {
	line := f.find_line(pos)
	return line, pos-f.line_offsets[line-1]+1
}

// return line when passed pos (binary search)
// NOTE: only used for error conditions
// therefore search speed is not an issue
pub fn (f &File) find_line(pos int) int {
	mut min, mut max := 0, f.line_offsets.len
	for min < max {
		mid := (min+max)/2
		// println('# min: $min, mid: $mid, max: $max')
		if f.line_offsets[mid] <= pos {
			min = mid + 1
		} else {
			max = mid
		}
	}
	return min
}
