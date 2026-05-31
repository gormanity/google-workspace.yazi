test_static_checks() {
	run_capture sh -n "$repo_root/open" "$repo_root/resolve-upload-dir"
	assert_status 0 || return 1

	run_capture luac -p "$repo_root/main.lua" "$repo_root/helper-scripts.lua"
	assert_status 0 || return 1

	HELPER_SCRIPTS=$repo_root/helper-scripts.lua lua -e 'local scripts=assert(dofile(os.getenv("HELPER_SCRIPTS"))); io.write(assert(scripts.open))' >"$tmp/expected-open" || return 1
	HELPER_SCRIPTS=$repo_root/helper-scripts.lua lua -e 'local scripts=assert(dofile(os.getenv("HELPER_SCRIPTS"))); io.write(assert(scripts.resolve_upload_dir))' >"$tmp/expected-resolve" || return 1
	cmp -s "$repo_root/open" "$tmp/expected-open" || {
		fail "open is not in sync with helper-scripts.lua"
		return 1
	}
	cmp -s "$repo_root/resolve-upload-dir" "$tmp/expected-resolve" || {
		fail "resolve-upload-dir is not in sync with helper-scripts.lua"
		return 1
	}
}

register_test test_static_checks
