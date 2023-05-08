module main

fn test_main() {
	string_literal_raw_a := r'raw string Literal b'
	string_literal_inter_a := 'a == abc${a:2f} && and b == abc${b}...'
	string_literal_inter_b := '${@MOD}.${@METHOD} - ${fn_call(unsafe { 1 })}'
	string_literal_inter_c := '${mod.fn_call(1)} | ${mod.fn_call('a').join(' ')} > out'
	// TODO: fix for scanner .skip_interpolation mode. need to count {
	// string_literal_inter_d := '${mod.fn_call(1)} | ${mod.fn_call(unsafe {1} + mod.fn_call('a')).join(' ')} > out'
	string_literal_inter_e := "${mod.fn_call(1)} | ${mod.fn_call(mod.fn_call('a')).join(' ')} > out"
}

fn test_basic() {
	pi := 3.14159265359
	pi_name := 'Pi'
	pi_symbol := `π`
	pi_description := '$pi_name (${pi_symbol}) is a mathematical constant that is the ratio of a circle\'s circumference to its diameter, approximately equal ${pi:.5}.'
}

