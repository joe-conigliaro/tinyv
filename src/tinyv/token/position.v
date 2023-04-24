// Copyright (c) 2020-2023 Joe Conigliaro. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module token

// TODO: finish fileset / file / base pos etc

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
	files []&File
}

pub fn (fs &FileSet) add_file(filename string, base int, size int) &File {
	file := &File{name: filename, size: size, line_offsets: [0]}
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
	return f.position(pos).line
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

// binary search for line
// return line, column when passed pos
pub fn (f &File) find_line_and_column(pos int) (int, int) {
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
	return min, pos-f.line_offsets[min-1]+1
}
