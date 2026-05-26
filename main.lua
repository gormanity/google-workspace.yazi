local CONFIG_HOME = os.getenv("YAZI_CONFIG_HOME") or (os.getenv("HOME") .. "/.config/yazi")
local CONFIG_PATH = CONFIG_HOME .. "/google-workspace.yazi.env"
local OPEN = CONFIG_HOME .. "/plugins/google-workspace.yazi/open"
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

local selected_or_hovered = ya.sync(function()
	local urls = {}

	for _, url in pairs(cx.active.selected) do
		urls[#urls + 1] = tostring(url)
	end

	if #urls == 0 then
		local hovered = cx.active.current.hovered
		if hovered then
			urls[#urls + 1] = tostring(hovered.url)
		end
	end

	return urls
end)

local function upload()
	local urls = selected_or_hovered()
	if #urls == 0 then
		notify("error", "No file is selected or hovered.")
		return
	end

	local command = Command(OPEN)
	for _, url in ipairs(urls) do
		command:arg(url)
	end

	local output, err = command:output()
	if not output then
		notify("error", tostring(err))
		return
	end

	if not output.status.success then
		local stderr = output.stderr and tostring(output.stderr) or "Upload failed."
		notify("error", stderr:gsub("%s+$", ""))
	end
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
		if args[1] == "upload" then
			upload()
			return
		end

		ya.mgr_emit("open", {})
	end,
}
