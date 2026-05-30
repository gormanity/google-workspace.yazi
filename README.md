# google-workspace.yazi

A Yazi plugin and opener for Google Workspace and Google Drive workflows.

## Features

- Resolve Google Drive shortcut files in local Drive folders and open them in
  the browser
- Upload local files to Drive from a Yazi confirmation prompt, then open them in
  the browser
- Optionally convert Office and OpenDocument files to native Google Workspace
  formats while uploading
- Jump from Yazi to the default Drive upload folder
- Open the configured Drive upload folder in the browser
- Bind an upload-only command without using file opener rules

## Requirements

- [`Yazi`](https://github.com/sxyazi/yazi)
- One of the following Drive CLIs:
  - [`googleworkspace-cli`](https://github.com/googleworkspace/cli), providing
    `gws`
  - [`gogcli`](https://github.com/openclaw/gogcli), providing `gog`
- [`jq`](https://github.com/jqlang/jq)

Complete Drive authentication in your chosen CLI before using upload or
folder-resolution workflows.

Platform notes:

- On macOS, the helper scripts use the system `open` command. `cd-upload-dir`
  can find Google Drive for Desktop's local My Drive folder automatically.
- On Linux, install `xdg-open` or `gio` for opening URLs.
- Use `--url-opener` when you want a specific command to open returned Drive
  URLs, such as `wslview` in WSL. The command receives the URL as its first
  argument.
- On Linux, WSL, or any setup using a custom Drive sync folder or mount,
  configure `drive_root` if you want `cd-upload-dir` to map Drive folder IDs
  back to local paths.

## Installation

### Using `ya pkg`

```sh
ya pkg add gormanity/google-workspace
```

### Manual Installation

```sh
git clone https://github.com/gormanity/google-workspace.yazi.git \
  "${YAZI_CONFIG_HOME:-$HOME/.config/yazi}/plugins/google-workspace.yazi"
```

## Configuration

### Plugin Options

Configure plugin behavior in `~/.config/yazi/init.lua`:

```lua
require("google-workspace"):setup({
  upload_dir_id = "<Drive folder ID>",
  drive_root = "$HOME/Drive/My Drive",
  drive_cli = "auto",
  url_opener = "wslview",
  convert = false,
  assume_yes = false,
  overwrite = "prompt",
})
```

All options are optional.

The setup call also writes the shell helpers used by the opener and plugin
commands. This is required for `ya pkg` installs because Yazi's package manager
only installs plugin Lua files and documentation.

| Option          | Description                                                                                      | Default                    |
| --------------- | ------------------------------------------------------------------------------------------------ | -------------------------- |
| `upload_dir_id` | Drive folder ID to upload files into                                                             | Drive root                 |
| `drive_root`    | Local My Drive root for `cd-upload-dir` on non-macOS or custom sync/mount setups                 | Auto-detected My Drive     |
| `drive_cli`     | Drive CLI backend: `auto`, `gws`, or `gog`                                                       | `auto` (`gws`, then `gog`) |
| `url_opener`    | Command to open Drive URLs; receives the URL as its first argument                               | System URL opener          |
| `convert`       | Convert supported Office and OpenDocument files to native Google Workspace files                 | `false`                    |
| `assume_yes`    | Skip the upload confirmation dialog                                                              | `false`                    |
| `overwrite`     | What to do when an upload finds a same-name Drive file: `prompt`, `always`, `never`, or `cancel` | `prompt`                   |

On Linux, WSL, or any setup where the local Drive folder is not in the macOS
Google Drive for Desktop location, set `drive_root`. The path should point at
the local directory that corresponds to Drive's My Drive root, whether it comes
from Google Drive for Desktop, `rclone mount`, a FUSE mount, or another sync
client. Absolute paths, `~`, `$HOME`, and `${HOME}` are supported.

### Opener

Add a `google_workspace` opener to `~/.config/yazi/yazi.toml`:

```toml
[opener]
google_workspace = [
  { run = '${YAZI_CONFIG_HOME:-$HOME/.config/yazi}/plugins/google-workspace.yazi/open "$@"', desc = "Google Workspace", orphan = true },
]
```

When this opener runs inside Yazi, the helper publishes the request back to the
plugin so confirmations, status messages, and errors can use Yazi's UI.

Then attach it to the file extensions you want Yazi to open with Google
Workspace:

```toml
[open]
prepend_rules = [
  { name = "*.gdoc", use = "google_workspace" },
  { name = "*.gsheet", use = "google_workspace" },
  { name = "*.gslides", use = "google_workspace" },
  { name = "*.docx", use = "google_workspace" },
  { name = "*.xlsx", use = "google_workspace" },
  { name = "*.pptx", use = "google_workspace" },
]
```

### Keybinding

To jump to the configured Drive upload folder from Yazi, add a keybinding to
`~/.config/yazi/keymap.toml`:

```toml
[[mgr.prepend_keymap]]
on   = [ "g", "d" ]
run  = "plugin google-workspace cd-upload-dir"
desc = "Go to Google Drive upload directory"
```

To upload the selected files, or the hovered file when nothing is selected,
without opening the uploaded Drive file in the browser:

```toml
[[mgr.prepend_keymap]]
on   = [ "u", "g" ]
run  = "plugin google-workspace upload"
desc = "Upload to Google Drive"
```

To open the configured Drive upload folder in the browser:

```toml
[[mgr.prepend_keymap]]
on   = [ "g", "D" ]
run  = "plugin google-workspace open-upload-dir"
desc = "Open Google Drive upload directory"
```

### Advanced Configuration

The `init.lua` setup is the default configuration for the plugin commands and
the standard `google_workspace` opener. Individual opener commands can still
pass flags to override those defaults for a specific file rule. Those flags are
passed through the Yazi bridge before the helper runs.

For example, to convert Word documents but upload Excel files in their original
format:

```toml
[opener]
google_workspace_docs = [
  { run = '${YAZI_CONFIG_HOME:-$HOME/.config/yazi}/plugins/google-workspace.yazi/open --convert "$@"', desc = "Google Docs", orphan = true },
]

google_workspace_sheets = [
  { run = '${YAZI_CONFIG_HOME:-$HOME/.config/yazi}/plugins/google-workspace.yazi/open "$@"', desc = "Google Sheets", orphan = true },
]

[open]
prepend_rules = [
  { name = "*.doc", use = "google_workspace_docs" },
  { name = "*.docx", use = "google_workspace_docs" },
  { name = "*.xls", use = "google_workspace_sheets" },
  { name = "*.xlsx", use = "google_workspace_sheets" },
]
```

Direct opener flags only apply when that opener is used. Plugin commands such as
`plugin google-workspace upload` and `plugin google-workspace cd-upload-dir` use
the `init.lua` setup.

Use `--overwrite prompt`, `--overwrite always`, `--overwrite never`, or
`--overwrite cancel` in an opener command to override the configured overwrite
policy for a specific file rule.

## Usage

### Open Google Workspace Shortcuts

Use the configured Yazi opener on Google Drive shortcut files:

- `.gdoc`
- `.gsheet`
- `.gslides`
- `.gdraw`
- `.gform`
- `.gmap`
- `.gsite`
- `.glink`

The opener reads the embedded Drive URL from the shortcut and opens it with the
system URL opener. Current Drive for Desktop shortcut files that contain a Drive
file ID are opened by constructing the matching Google Workspace URL locally.

### Upload Local Files

Use the configured opener on regular local files to upload them to Drive and
open the resulting Drive URL in the browser.

The opener asks for confirmation before uploading unless `assume_yes = true` is
set in `init.lua`. When the opener runs inside Yazi, the confirmation is shown
inside Yazi.

If the upload destination already contains a non-trashed Drive file with the
same name, `overwrite = "prompt"` lets you replace the Drive file, upload
another same-name Drive file, or cancel the upload. `overwrite = "always"`
replaces it without a prompt, `overwrite = "never"` uploads another same-name
Drive file without replacing it, and `overwrite = "cancel"` cancels the upload.

You can also run `plugin google-workspace upload` from a keymap to upload the
selected files, or the hovered file when nothing is selected, without opening
the uploaded Drive file in the browser. This uses the same configuration from
`init.lua` and does not require `[open]` rules.

### Convert Files

Set `convert = true` in `init.lua` to convert supported Office and OpenDocument
files to native Google Workspace files:

- Documents: `.doc`, `.docx`, `.odt`, `.rtf`
- Spreadsheets: `.xls`, `.xlsm`, `.xlsx`, `.ods`, `.xsv`
- Presentations: `.ppt`, `.pptx`, `.pot`, `.potx`, `.pps`, `.ppsx`, `.odp`

By default, Office and OpenDocument files upload as original Drive files. The
same is true for other local files, such as PDFs and images.

### Navigate to the Upload Folder

Run the bindable command:

```toml
plugin google-workspace cd-upload-dir
```

The plugin reads `upload_dir_id` and `drive_root` from `init.lua`, resolves the
Drive folder through the configured Drive CLI, maps it to the matching local
Drive folder, and navigates Yazi there.

If no upload folder is configured, it navigates to the local My Drive root when
one can be found or configured.

Run `plugin google-workspace open-upload-dir` to open the configured Drive
upload folder in the browser. If no upload folder is configured, it opens Drive
root.

## How It Works

1. Yazi dispatches matching files to the static `google_workspace` opener in
   `yazi.toml`.
2. Inside a Yazi session, the generated `open` helper publishes the opener
   request back to the plugin with `ya pub`, and the plugin receives it with
   `ps.sub_remote`.
3. `require("google-workspace"):setup(...)` writes the configured options to a
   generated file under `YAZI_CONFIG_HOME` and materializes the shell helpers
   used by the opener.
4. The plugin uses Yazi confirmations and notifications, then calls the helper
   with direct mode enabled.
5. The generated `open` helper reads the generated config and opens Google
   shortcut URLs directly.
6. For regular local files, `open` uploads the file with `gws` or `gog`, then
   opens the returned Drive URL.
7. `plugin google-workspace upload` calls the generated `open` helper with
   browser opening disabled for the selected files, or the hovered file when
   nothing is selected.
8. `plugin google-workspace open-upload-dir` opens the configured upload folder
   URL, or Drive root when no upload folder is configured.
9. `plugin google-workspace` without arguments delegates to Yazi's built-in
   `open`, so it uses the same `[open]` and `[opener]` rules.
10. `plugin google-workspace cd-upload-dir` runs `resolve-upload-dir` and emits
    a Yazi `cd` command for the resolved local Drive path.

## Development

Run the lightweight checks after edits:

```sh
sh -n open resolve-upload-dir
luac -p main.lua helper-scripts.lua
```

When testing from an installed Yazi config, also run:

```sh
yazi --debug
```

Use `gws --dry-run` for request-shape checks before live uploads.

## License

MIT

## Credits

Built for using Google Workspace files from Yazi while keeping opener
configuration in Yazi's normal static config.
