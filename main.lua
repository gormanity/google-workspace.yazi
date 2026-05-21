local RESOLVE_UPLOAD_DIR = os.getenv("HOME") .. "/.config/yazi/plugins/google-workspace.yazi/resolve-upload-dir"

local function notify(level, content)
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
	setup = function() end,

	entry = function(_, job)
		local args = job.args or {}
		if args[1] == "cd-upload-dir" then
			cd_upload_dir()
			return
		end

		ya.mgr_emit("open", {})
	end,
}
