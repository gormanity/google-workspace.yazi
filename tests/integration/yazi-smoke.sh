test_yazi_launch_runs_plugin_setup() {
	reset_case
	mkdir -p "$cfg/plugins/google-workspace.yazi" "$tmp/yazi-entry"
	cp "$repo_root/main.lua" "$repo_root/helper-scripts.lua" "$cfg/plugins/google-workspace.yazi/"
	cat >"$cfg/init.lua" <<'LUA'
require("google-workspace"):setup({
  upload_dir_id = "folder-child",
  drive_root = "$HOME/Drive/My Drive",
  drive_cli = "gog",
  url_opener = "fake-open",
  convert = true,
  assume_yes = true,
  overwrite = "never",
})
LUA

	run_capture env YAZI_CONFIG_HOME="$cfg" HOME="$home" TEST_ENTRY="$tmp/yazi-entry" expect -c '
log_user 0
set timeout 10
spawn env YAZI_CONFIG_HOME=$env(YAZI_CONFIG_HOME) HOME=$env(HOME) TERM=xterm-256color yazi $env(TEST_ENTRY)
after 5000
send "q"
expect {
  eof {}
  timeout { close; wait; exit 124 }
}
set result [wait]
exit [lindex $result 3]
'
	assert_status 0 || return 1

	[ -x "$cfg/plugins/google-workspace.yazi/open" ] || {
		fail "Yazi launch did not write executable open helper"
		return 1
	}
	[ -x "$cfg/plugins/google-workspace.yazi/resolve-upload-dir" ] || {
		fail "Yazi launch did not write executable resolve-upload-dir helper"
		return 1
	}
	config=$(file_contents "$cfg/google-workspace.yazi.env")
	assert_contains "$config" "GOOGLE_WORKSPACE_UPLOAD_DIR='folder-child'" "Yazi setup config" || return 1
	assert_contains "$config" "GOOGLE_WORKSPACE_OVERWRITE_POLICY='never'" "Yazi setup config" || return 1
}

register_test test_yazi_launch_runs_plugin_setup
