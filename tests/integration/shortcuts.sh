test_shortcut_url_opens_embedded_url() {
	reset_case
	write_config "" "" "gog" "fake-open" "" "1" "prompt"
	printf '%s\n' '{"url":"https://docs.google.com/document/d/doc-id/edit"}' >"$tmp/sample.gdoc"

	run_capture "$repo_root/open" --direct "$tmp/sample.gdoc"
	assert_status 0 || return 1
	assert_eq "https://docs.google.com/document/d/doc-id/edit" "$(file_contents "$log/opened")" "opened URL"
}

test_shortcut_doc_id_builds_workspace_url() {
	reset_case
	write_config "" "" "gog" "fake-open" "" "1" "prompt"
	printf '%s\n' '{"doc_id":"sheet-id","resource_key":"resource-123"}' >"$tmp/sample.gsheet"

	run_capture "$repo_root/open" --direct "$tmp/sample.gsheet"
	assert_status 0 || return 1
	assert_eq "https://docs.google.com/spreadsheets/d/sheet-id/edit?resourcekey=resource-123" "$(file_contents "$log/opened")" "opened URL"
}

test_explicit_url_opening() {
	reset_case
	write_config "" "" "gog" "fake-open" "" "1" "prompt"

	run_capture "$repo_root/open" --direct --url "https://drive.google.com/drive/my-drive"
	assert_status 0 || return 1
	assert_eq "https://drive.google.com/drive/my-drive" "$(file_contents "$log/opened")" "opened URL"
}

register_test test_shortcut_url_opens_embedded_url
register_test test_shortcut_doc_id_builds_workspace_url
register_test test_explicit_url_opening
