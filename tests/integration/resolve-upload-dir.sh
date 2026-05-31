test_resolve_upload_dir_without_folder_uses_drive_root() {
	reset_case
	mkdir -p "$home/Drive/My Drive"
	write_config "" "$home/Drive/My Drive" "gog" "fake-open" "" "1" "prompt"

	run_capture "$repo_root/resolve-upload-dir"
	assert_status 0 || return 1
	assert_eq "$home/Drive/My Drive" "$cmd_stdout" "resolved path"
}

test_resolve_upload_dir_maps_folder_chain_to_local_path() {
	reset_case
	mkdir -p "$home/Drive/My Drive/Invoices"
	write_config "folder-child" "$home/Drive/My Drive" "gog" "fake-open" "" "1" "prompt"

	run_capture "$repo_root/resolve-upload-dir"
	assert_status 0 || return 1
	assert_eq "$home/Drive/My Drive/Invoices" "$cmd_stdout" "resolved path" || return 1
	assert_contains "$(file_contents "$log/gog")" "drive	get	folder-child" "gog folder lookup log"
}

register_test test_resolve_upload_dir_without_folder_uses_drive_root
register_test test_resolve_upload_dir_maps_folder_chain_to_local_path
