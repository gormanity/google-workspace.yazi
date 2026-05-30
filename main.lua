local CONFIG_HOME = os.getenv("YAZI_CONFIG_HOME") or (os.getenv("HOME") .. "/.config/yazi")
local CONFIG_PATH = CONFIG_HOME .. "/google-workspace.yazi.env"
local PLUGIN_DIR = CONFIG_HOME .. "/plugins/google-workspace.yazi"
local HELPER_SCRIPTS = PLUGIN_DIR .. "/helper-scripts.lua"
local OPEN = PLUGIN_DIR .. "/open"
local RESOLVE_UPLOAD_DIR = PLUGIN_DIR .. "/resolve-upload-dir"
local OPEN_EVENT = "google-workspace-open"
local notify
local subscribed_open_event = false

local function shell_quote(value)
	value = tostring(value or "")
	return "'" .. value:gsub("'", [['"'"']]) .. "'"
end

local function bool_value(value)
	return value and "1" or ""
end

local function normalize_overwrite_policy(value)
	value = tostring(value or "prompt")
	if value == "prompt" or value == "always" or value == "never" then
		return value
	end

	notify("warn", "Invalid overwrite policy '" .. value .. "'. Using prompt.")
	return "prompt"
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
			"GOOGLE_WORKSPACE_OVERWRITE_POLICY=" .. shell_quote(normalize_overwrite_policy(opts.overwrite)),
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

local function basename(path)
	return tostring(path or ""):gsub("/+$", ""):match("([^/]+)$") or tostring(path or "")
end

local function extension(path)
	local name = basename(path)
	local ext = name:match("%.([^.]*)$")
	if not ext or ext == "" then
		return nil
	end

	return ext:lower()
end

local function is_workspace_shortcut(path)
	local ext = extension(path)
	return ext == "gdoc"
		or ext == "gdraw"
		or ext == "gform"
		or ext == "glink"
		or ext == "gmap"
		or ext == "gsheet"
		or ext == "gsite"
		or ext == "gslides"
end

local function is_file(path)
	local file = io.open(tostring(path or ""), "r")
	if not file then
		return false
	end

	file:close()
	return true
end

local function hex_encode(value)
	return (tostring(value or ""):gsub(".", function(char)
		return string.format("%02x", string.byte(char))
	end))
end

local function hex_decode(value)
	return (tostring(value or ""):gsub("%x%x", function(byte)
		return string.char(tonumber(byte, 16))
	end))
end

local function encode_args(args)
	local encoded = {}
	for _, arg in ipairs(args or {}) do
		encoded[#encoded + 1] = hex_encode(arg)
	end

	return table.concat(encoded, ",")
end

local function decode_args(value)
	local args = {}
	for encoded in tostring(value or ""):gmatch("[^,]+") do
		args[#args + 1] = hex_decode(encoded)
	end

	return args
end

local function normalize_remote_args(body)
	local args = {}
	if type(body) == "table" then
		for _, arg in ipairs(body) do
			if arg ~= nil then
				args[#args + 1] = tostring(arg)
			end
		end
	elseif body ~= nil and tostring(body) ~= "" then
		args[#args + 1] = tostring(body)
	end

	return args
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

local function assume_yes()
	return config_value("GOOGLE_WORKSPACE_ASSUME_YES") == "1"
end

local function configured_overwrite_policy()
	return normalize_overwrite_policy(config_value("GOOGLE_WORKSPACE_OVERWRITE_POLICY"))
end

local function confirm_upload(path)
	if assume_yes() then
		return true
	end

	return ya.confirm({
		pos = { "center", w = 60, h = 8 },
		title = "Google Workspace",
		body = "Upload " .. basename(path) .. " to Google Drive?",
	})
end

local function confirm_replace(path, name)
	return ya.confirm({
		pos = { "center", w = 62, h = 9 },
		title = "Google Workspace",
		body = "A Drive file named " .. name .. " already exists. Replace it with " .. basename(path) .. "?",
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

local function parse_open_args(args)
	local parsed = {
		args = {},
		helper_args = {},
		paths = {},
		assume_yes = false,
		no_open = false,
		overwrite = nil,
		url_mode = false,
	}

	local i = 1
	while i <= #args do
		local arg = args[i]
		parsed.args[#parsed.args + 1] = arg

		if arg == "--assume-yes" then
			parsed.helper_args[#parsed.helper_args + 1] = arg
			parsed.assume_yes = true
			i = i + 1
		elseif arg == "--no-open" then
			parsed.helper_args[#parsed.helper_args + 1] = arg
			parsed.no_open = true
			i = i + 1
		elseif arg == "--convert" then
			parsed.helper_args[#parsed.helper_args + 1] = arg
			i = i + 1
		elseif arg == "--overwrite" then
			parsed.helper_args[#parsed.helper_args + 1] = arg
			if args[i + 1] then
				parsed.args[#parsed.args + 1] = args[i + 1]
				parsed.helper_args[#parsed.helper_args + 1] = args[i + 1]
				parsed.overwrite = args[i + 1]
			end
			i = i + 2
		elseif arg == "--no-notify" or arg == "--direct" then
			i = i + 1
		elseif arg == "--url" then
			parsed.helper_args[#parsed.helper_args + 1] = arg
			parsed.url_mode = true
			if args[i + 1] then
				parsed.args[#parsed.args + 1] = args[i + 1]
				parsed.helper_args[#parsed.helper_args + 1] = args[i + 1]
			end
			i = i + 2
		elseif arg == "--upload-dir-id" or arg == "--drive-cli" or arg == "--url-opener" then
			parsed.helper_args[#parsed.helper_args + 1] = arg
			if args[i + 1] then
				parsed.args[#parsed.args + 1] = args[i + 1]
				parsed.helper_args[#parsed.helper_args + 1] = args[i + 1]
			end
			i = i + 2
		elseif arg == "--" then
			i = i + 1
			while i <= #args do
				parsed.args[#parsed.args + 1] = args[i]
				parsed.paths[#parsed.paths + 1] = args[i]
				i = i + 1
			end
		elseif arg:sub(1, 1) == "-" then
			parsed.helper_args[#parsed.helper_args + 1] = arg
			i = i + 1
		else
			parsed.paths[#parsed.paths + 1] = arg
			i = i + 1
		end
	end

	return parsed
end

local function run_open_helper(args)
	local command = Command(OPEN):arg("--direct"):arg("--assume-yes"):arg("--no-notify"):arg("--skip-overwrite-check")
	for _, arg in ipairs(args) do
		command:arg(arg)
	end

	local output, err = command:output()
	if not output then
		notify("error", tostring(err))
		return false
	end

	if not output.status.success then
		local stderr = output.stderr and tostring(output.stderr) or "Google Workspace action failed."
		notify("error", stderr:gsub("%s+$", ""))
		return false
	end

	return true
end

local function find_existing_file(path, parsed)
	local command = Command(OPEN):arg("--direct"):arg("--no-notify"):arg("--find-existing")
	for _, arg in ipairs(parsed.helper_args) do
		if arg ~= "--assume-yes" and arg ~= "--no-open" then
			command:arg(arg)
		end
	end
	command:arg("--"):arg(path)

	local output, err = command:output()
	if not output then
		notify("error", tostring(err))
		return nil, false
	end

	if not output.status.success then
		local stderr = output.stderr and tostring(output.stderr) or "Could not check Google Drive for existing files."
		notify("error", stderr:gsub("%s+$", ""))
		return nil, false
	end

	local stdout = tostring(output.stdout):gsub("%s+$", "")
	if stdout == "" then
		return nil, true
	end

	local id, name = stdout:match("^([^\t\r\n]+)\t(.*)$")
	if not id then
		notify("error", "Could not parse existing Google Drive file response.")
		return nil, false
	end

	return { id = id, name = name ~= "" and name or basename(path) }, true
end

local function open_with_yazi(args)
	local parsed = parse_open_args(args)
	local overwrite_policy = normalize_overwrite_policy(parsed.overwrite or configured_overwrite_policy())

	if parsed.url_mode then
		run_open_helper(parsed.helper_args)
		return
	end

	if #parsed.paths == 0 then
		notify("error", "No file was provided.")
		return
	end

	for _, path in ipairs(parsed.paths) do
		local uploads_file = is_file(path) and not is_workspace_shortcut(path)
		local replace_file_id = nil
		local proceed = true

		if uploads_file then
			local existing, ok = find_existing_file(path, parsed)
			if not ok then
				proceed = false
			elseif existing then
				if overwrite_policy == "always" then
					replace_file_id = existing.id
				elseif overwrite_policy == "never" then
					proceed = false
					notify("warn", "Upload canceled: " .. existing.name .. " already exists in Google Drive.")
				elseif confirm_replace(path, existing.name) then
					replace_file_id = existing.id
				else
					proceed = false
					notify("warn", "Upload canceled: " .. basename(path))
				end
			elseif not parsed.assume_yes and not confirm_upload(path) then
				proceed = false
				notify("warn", "Upload canceled: " .. basename(path))
			end
		end

		if proceed then
			local helper_args = {}
			for _, arg in ipairs(parsed.helper_args) do
				helper_args[#helper_args + 1] = arg
			end
			if replace_file_id then
				helper_args[#helper_args + 1] = "--replace-file-id"
				helper_args[#helper_args + 1] = replace_file_id
			end
			helper_args[#helper_args + 1] = "--"
			helper_args[#helper_args + 1] = path

			if run_open_helper(helper_args) and uploads_file then
				notify("info", "Uploaded " .. basename(path) .. " to Google Drive.")
			end
		end
	end
end

local function open_upload_dir()
	local folder_id = config_value("GOOGLE_WORKSPACE_UPLOAD_DIR")
	local url = "https://drive.google.com/drive/my-drive"
	if folder_id and folder_id ~= "" then
		url = "https://drive.google.com/drive/folders/" .. folder_id
	end

	local output, err = Command(OPEN):arg("--direct"):arg("--no-notify"):arg("--url"):arg(url):output()
	if not output then
		notify("error", tostring(err))
		return
	end

	if not output.status.success then
		local stderr = output.stderr and tostring(output.stderr) or "Could not open Google Drive upload directory."
		notify("error", stderr:gsub("%s+$", ""))
	end
end

local function upload()
	local urls = selected_or_hovered()
	if #urls == 0 then
		notify("error", "No file is selected or hovered.")
		return
	end

	local args = { "--no-open" }
	for _, url in ipairs(urls) do
		args[#args + 1] = url
	end

	open_with_yazi(args)
end

local function subscribe_open_event(plugin_id)
	if subscribed_open_event or not plugin_id then
		return
	end

	local ok, err = pcall(ps.sub_remote, OPEN_EVENT, function(body)
		local args = normalize_remote_args(body)
		if #args == 0 then
			return
		end

		ya.emit("plugin", { plugin_id, "open-remote " .. encode_args(args) })
	end)
	if ok then
		subscribed_open_event = true
	elseif not tostring(err):find("called twice", 1, true) then
		notify("error", "Could not subscribe to opener events: " .. tostring(err))
	end
end

return {
	setup = function(self, opts)
		if opts == nil and type(self) == "table" and not self.entry then
			opts = self
		end

		write_config(opts)
		write_helper_scripts()
		if type(self) == "table" and self._id then
			subscribe_open_event(self._id)
		end
	end,

	entry = function(_, job)
		local args = job.args or {}
		if args[1] == "open-remote" then
			open_with_yazi(decode_args(args[2]))
			return
		end
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
