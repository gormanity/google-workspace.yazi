test_overwrite_always_replaces_existing_file() {
	reset_case
	write_config "upload-folder" "" "gog" "fake-open" "" "1" "prompt"
	printf '%s\n' "xlsx" >"$tmp/report.xlsx"
	TEST_EXISTING_ID=existing-id
	TEST_EXISTING_NAME=report.xlsx
	export TEST_EXISTING_ID TEST_EXISTING_NAME

	run_capture "$repo_root/open" --direct --overwrite always --no-open --no-notify --assume-yes "$tmp/report.xlsx"
	assert_status 0 || return 1
	gog_log=$(file_contents "$log/gog")
	assert_contains "$gog_log" "drive	ls" "gog existing-file log" || return 1
	assert_contains "$gog_log" "--replace	existing-id" "gog replacement log"
}

test_overwrite_never_uploads_same_name_file() {
	reset_case
	write_config "upload-folder" "" "gog" "fake-open" "" "1" "prompt"
	printf '%s\n' "xlsx" >"$tmp/report.xlsx"
	TEST_EXISTING_ID=existing-id
	TEST_EXISTING_NAME=report.xlsx
	export TEST_EXISTING_ID TEST_EXISTING_NAME

	run_capture "$repo_root/open" --direct --overwrite never --no-open --no-notify --assume-yes "$tmp/report.xlsx"
	assert_status 0 || return 1
	gog_log=$(file_contents "$log/gog")
	assert_contains "$gog_log" "drive	ls" "gog existing-file log" || return 1
	assert_contains "$gog_log" "drive	upload	$tmp/report.xlsx" "gog upload log" || return 1
	assert_not_contains "$gog_log" "--replace	existing-id" "gog upload log"
}

test_overwrite_cancel_stops_upload() {
	reset_case
	write_config "upload-folder" "" "gog" "fake-open" "" "1" "prompt"
	printf '%s\n' "xlsx" >"$tmp/report.xlsx"
	TEST_EXISTING_ID=existing-id
	TEST_EXISTING_NAME=report.xlsx
	export TEST_EXISTING_ID TEST_EXISTING_NAME

	run_capture "$repo_root/open" --direct --overwrite cancel --no-open --no-notify --assume-yes "$tmp/report.xlsx"
	assert_status 1 || return 1
	gog_log=$(file_contents "$log/gog")
	assert_contains "$gog_log" "drive	ls" "gog existing-file log" || return 1
	assert_not_contains "$gog_log" "drive	upload" "gog upload log"
}

register_test test_overwrite_always_replaces_existing_file
register_test test_overwrite_never_uploads_same_name_file
register_test test_overwrite_cancel_stops_upload
