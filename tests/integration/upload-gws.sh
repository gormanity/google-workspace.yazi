test_auto_drive_cli_prefers_gws() {
	reset_case
	write_config "upload-folder" "" "auto" "fake-open" "" "1" "prompt"
	printf '%s\n' "pdf" >"$tmp/report.pdf"

	run_capture "$repo_root/open" --direct --no-open --no-notify --assume-yes --skip-overwrite-check "$tmp/report.pdf"
	assert_status 0 || return 1
	assert_contains "$(file_contents "$log/gws")" "drive	files	create" "gws upload log" || return 1
	assert_eq "" "$(file_contents "$log/gog")" "gog log"
}

test_gws_convert_xlsx_builds_metadata() {
	reset_case
	write_config "upload-folder" "" "gws" "fake-open" "" "1" "prompt"
	printf '%s\n' "xlsx" >"$tmp/numbers.xlsx"

	run_capture "$repo_root/open" --direct --convert --no-open --no-notify --assume-yes --skip-overwrite-check "$tmp/numbers.xlsx"
	assert_status 0 || return 1
	assert_eq "numbers" "$cmd_stdout" "uploaded name" || return 1
	gws_log=$(file_contents "$log/gws")
	assert_contains "$gws_log" "drive	files	create" "gws upload log" || return 1
	assert_contains "$gws_log" "application/vnd.google-apps.spreadsheet" "gws metadata log"
}

register_test test_auto_drive_cli_prefers_gws
register_test test_gws_convert_xlsx_builds_metadata
