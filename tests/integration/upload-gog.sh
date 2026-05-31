test_gog_upload_no_open_reports_uploaded_name() {
	reset_case
	write_config "upload-folder" "" "gog" "fake-open" "" "1" "prompt"
	printf '%s\n' "pdf" >"$tmp/report.pdf"

	run_capture "$repo_root/open" --direct --no-open --no-notify --assume-yes --skip-overwrite-check "$tmp/report.pdf"
	assert_status 0 || return 1
	assert_eq "report.pdf" "$cmd_stdout" "uploaded name" || return 1
	assert_eq "" "$(file_contents "$log/opened")" "opened URL log" || return 1
	assert_contains "$(file_contents "$log/gog")" "drive	upload	$tmp/report.pdf" "gog upload log"
}

test_gog_convert_docx_uses_native_doc_target() {
	reset_case
	write_config "upload-folder" "" "gog" "fake-open" "" "1" "prompt"
	printf '%s\n' "docx" >"$tmp/report.docx"

	run_capture "$repo_root/open" --direct --convert --no-open --no-notify --assume-yes --skip-overwrite-check "$tmp/report.docx"
	assert_status 0 || return 1
	assert_eq "report" "$cmd_stdout" "uploaded name" || return 1
	gog_log=$(file_contents "$log/gog")
	assert_contains "$gog_log" "--convert-to	doc" "gog upload log" || return 1
	assert_contains "$gog_log" "--name	report" "gog upload log"
}

test_gog_docx_without_convert_uploads_original_name() {
	reset_case
	write_config "upload-folder" "" "gog" "fake-open" "" "1" "prompt"
	printf '%s\n' "docx" >"$tmp/report.docx"

	run_capture "$repo_root/open" --direct --no-open --no-notify --assume-yes --skip-overwrite-check "$tmp/report.docx"
	assert_status 0 || return 1
	assert_eq "report.docx" "$cmd_stdout" "uploaded name" || return 1
	gog_log=$(file_contents "$log/gog")
	assert_not_contains "$gog_log" "--convert-to" "gog upload log" || return 1
	assert_contains "$gog_log" "--name	report.docx" "gog upload log"
}

register_test test_gog_upload_no_open_reports_uploaded_name
register_test test_gog_convert_docx_uses_native_doc_target
register_test test_gog_docx_without_convert_uploads_original_name
