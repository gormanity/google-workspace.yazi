local CONFIG_HOME = os.getenv("YAZI_CONFIG_HOME") or (os.getenv("HOME") .. "/.config/yazi")
local CONFIG_PATH = CONFIG_HOME .. "/google-workspace.yazi.env"
local RESOLVE_UPLOAD_DIR = CONFIG_HOME .. "/plugins/google-workspace.yazi/resolve-upload-dir"
local notify

local function shell_quote(value)
	value = tostring(value or "")
	return "'" .. value:gsub("'", [['"'"']]) .. "'"
end

local function bool_value(value)
	return value and "1" or ""
end

local function write_config(opts)
	opts = opts or {}

	local file, err = io.open(CONFIG_PATH, "w")
	if not file then
		notify("error", "Could not write Google Workspace config: " .. tostring(err))
		return
	end

	file:write("GOOGLE_WORKSPACE_UPLOAD_DIR=", shell_quote(opts.upload_dir_id), "\n")
	file:write("GOOGLE_WORKSPACE_DRIVE_ROOT=", shell_quote(opts.drive_root), "\n")
	file:write("GOOGLE_WORKSPACE_DRIVE_CLI=", shell_quote(opts.drive_cli or "auto"), "\n")
	file:write("GOOGLE_WORKSPACE_URL_OPENER=", shell_quote(opts.url_opener), "\n")
	file:write("GOOGLE_WORKSPACE_CONVERT=", shell_quote(bool_value(opts.convert)), "\n")
	file:write("GOOGLE_WORKSPACE_ASSUME_YES=", shell_quote(bool_value(opts.assume_yes)), "\n")
	file:close()
end

function notify(level, content)
	ya.notify({
		title = "Google Workspace",
		content = content,
		level = level,
		timeout = level == "error" and 7 or 5,
	})
end

local function cd_upload_dir()
	local command = Command(RESOLVE_UPLOAD_DIR)

	local output, err = command:output()
	if not output then
		notify("error", tostring(err))
		return
	end

	if not output.status.success then
		local stderr = output.stderr and tostring(output.stderr) or "Could not resolve Google Drive upload directory."
		notify("error", stderr:gsub("%s+$", ""))
		return
	end

	local path = tostring(output.stdout):gsub("%s+$", "")
	if path == "" then
		notify("error", "Could not resolve Google Drive upload directory.")
		return
	end

	ya.mgr_emit("cd", { path })
end

return {
	setup = function(self, opts)
		if opts == nil and type(self) == "table" and not self.entry then
			opts = self
		end

		write_config(opts)
	end,

	entry = function(_, job)
		local args = job.args or {}
		if args[1] == "cd-upload-dir" then
			cd_upload_dir()
			return
		end

		ya.mgr_emit("open", {})
	end,
}
