test_main_setup_materializes_helpers() {
	reset_case
	mkdir -p "$cfg/plugins/google-workspace.yazi"
	cp "$repo_root/helper-scripts.lua" "$cfg/plugins/google-workspace.yazi/helper-scripts.lua"

	YAZI_CONFIG_HOME=$cfg HOME=$home lua - "$repo_root/main.lua" <<'LUA'
ya = {
	notify = function(_) end,
	sync = function(fn) return fn end,
}
local plugin = assert(dofile(arg[1]))
plugin:setup({
	upload_dir_id = "folder-child",
	drive_root = "$HOME/Drive/My Drive",
	drive_cli = "gog",
	url_opener = "fake-open",
	convert = true,
	assume_yes = true,
	overwrite = "never",
})
LUA
	lua_status=$?
	if [ "$lua_status" -ne 0 ]; then
		fail "setup lua fixture exited with $lua_status"
		return 1
	fi

	[ -x "$cfg/plugins/google-workspace.yazi/open" ] || {
		fail "setup did not write executable open helper"
		return 1
	}
	[ -x "$cfg/plugins/google-workspace.yazi/resolve-upload-dir" ] || {
		fail "setup did not write executable resolve-upload-dir helper"
		return 1
	}
	config=$(file_contents "$cfg/google-workspace.yazi.env")
	assert_contains "$config" "GOOGLE_WORKSPACE_UPLOAD_DIR='folder-child'" "setup config" || return 1
	assert_contains "$config" "GOOGLE_WORKSPACE_OVERWRITE_POLICY='never'" "setup config" || return 1
}

register_test test_main_setup_materializes_helpers
