local CONFIG_HOME = os.getenv("YAZI_CONFIG_HOME") or (os.getenv("HOME") .. "/.config/yazi")
local CONFIG_PATH = CONFIG_HOME .. "/google-workspace.yazi.env"
local PLUGIN_DIR = CONFIG_HOME .. "/plugins/google-workspace.yazi"
local HELPER_SCRIPTS = PLUGIN_DIR .. "/helper-scripts.lua"
local OPEN = PLUGIN_DIR .. "/open"
local RESOLVE_UPLOAD_DIR = PLUGIN_DIR .. "/resolve-upload-dir"
local notify

local function shell_quote(value)
	value = tostring(value or "")
	return "'" .. value:gsub("'", [['"'"']]) .. "'"
end

local function bool_value(value)
	return value and "1" or ""
end

local function write_file(path, content)
	local file, err = io.open(path, "w")
	if not file then
		return false, err
	end

	file:write(content)
	if content:sub(-1) ~= "\n" then
		file:write("\n")
	end
	file:close()

	return true
end

local function chmod_executable(path)
	local ok, _, code = os.execute("chmod +x " .. shell_quote(path))
	return ok == true or ok == 0 or code == 0
end

local function write_config(opts)
	opts = opts or {}

	local ok, err = write_file(
		CONFIG_PATH,
		table.concat({
			"GOOGLE_WORKSPACE_UPLOAD_DIR=" .. shell_quote(opts.upload_dir_id),
			"GOOGLE_WORKSPACE_DRIVE_ROOT=" .. shell_quote(opts.drive_root),
			"GOOGLE_WORKSPACE_DRIVE_CLI=" .. shell_quote(opts.drive_cli or "auto"),
			"GOOGLE_WORKSPACE_URL_OPENER=" .. shell_quote(opts.url_opener),
			"GOOGLE_WORKSPACE_CONVERT=" .. shell_quote(bool_value(opts.convert)),
			"GOOGLE_WORKSPACE_ASSUME_YES=" .. shell_quote(bool_value(opts.assume_yes)),
			"",
		}, "\n")
	)
	if not ok then
		notify("error", "Could not write Google Workspace config: " .. tostring(err))
	end
end

local function load_helper_scripts()
	if type(loadfile) ~= "function" then
		return nil, "Lua loadfile is not available."
	end

	local chunk, err = loadfile(HELPER_SCRIPTS)
	if not chunk then
		return nil, err
	end

	local ok, scripts = pcall(chunk)
	if not ok then
		return nil, scripts
	end
	if type(scripts) ~= "table" or type(scripts.open) ~= "string" or type(scripts.resolve_upload_dir) ~= "string" then
		return nil, "helper-scripts.lua did not return the expected helper scripts."
	end

	return scripts
end

local function write_executable(path, content)
	local ok, err = write_file(path, content)
	if not ok then
		notify("error", "Could not write Google Workspace helper: " .. tostring(err))
		return
	end

	if not chmod_executable(path) then
		notify("error", "Could not make Google Workspace helper executable: " .. path)
	end
end

local function write_helper_scripts()
	local scripts, err = load_helper_scripts()
	if not scripts then
		notify("error", "Could not load Google Workspace helpers: " .. tostring(err))
		return
	end

	write_executable(OPEN, scripts.open)
	write_executable(RESOLVE_UPLOAD_DIR, scripts.resolve_upload_dir)
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

	local command = Command(OPEN):arg("--no-open")
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

local function config_value(name)
	local file = io.open(CONFIG_PATH, "r")
	if not file then
		return nil
	end

	for line in file:lines() do
		local value = line:match("^" .. name .. "='(.*)'$")
		if value then
			file:close()
			return (value:gsub([['"'"']], "'"))
		end
	end

	file:close()
	return nil
end

local function open_upload_dir()
	local folder_id = config_value("GOOGLE_WORKSPACE_UPLOAD_DIR")
	local url = "https://drive.google.com/drive/my-drive"
	if folder_id and folder_id ~= "" then
		url = "https://drive.google.com/drive/folders/" .. folder_id
	end

	local output, err = Command(OPEN):arg("--url"):arg(url):output()
	if not output then
		notify("error", tostring(err))
		return
	end

	if not output.status.success then
		local stderr = output.stderr and tostring(output.stderr) or "Could not open Google Drive upload directory."
		notify("error", stderr:gsub("%s+$", ""))
	end
end

return {
	setup = function(self, opts)
		if opts == nil and type(self) == "table" and not self.entry then
			opts = self
		end

		write_config(opts)
		write_helper_scripts()
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
		if args[1] == "open-upload-dir" then
			open_upload_dir()
			return
		end

		ya.mgr_emit("open", {})
	end,
}
