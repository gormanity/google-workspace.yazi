# google-workspace.yazi

Make Google Drive feel native in [Yazi](https://github.com/sxyazi/yazi).

`google-workspace.yazi` connects Yazi to common Google Drive workflows:

1. Open Google Drive shortcut files in the browser.
2. Upload local files to Google Drive.
3. Jump between Yazi, your local Drive folder, and the Drive folder in the
   browser.

It is not a Drive sync client and it does not replace Google Drive for Desktop,
`rclone`, `gws`, or `gog`. Instead, it gives Yazi a configurable bridge to the
Drive tools and folders you already use.

## What it does

### Open Google Drive shortcut files from Yazi

Google Drive sync folders store Docs, Sheets, Slides, Forms, Drawings, Maps,
Sites, and Drive links as small shortcut files:

- `.gdoc`
- `.gsheet`
- `.gslides`
- `.gdraw`
- `.gform`
- `.gmap`
- `.gsite`
- `.glink`

With this plugin, opening one of those files in Yazi opens the corresponding
Drive or Google Workspace file in your browser.

### Upload local files to Google Drive

Use Yazi to send local files to Drive without switching to the browser first.

You can upload:

- Office files such as `.docx`, `.xlsx`, and `.pptx`
- OpenDocument files such as `.odt`, `.ods`, and `.odp`
- PDFs
- images
- other regular local files

When uploads are triggered through the opener, the plugin opens the uploaded
Drive file in your browser. The `plugin google-workspace upload` command uploads
without opening the browser afterward.

It can also convert supported Office and OpenDocument files to native Google
Workspace formats while uploading:

- Word documents to Google Docs
- Excel spreadsheets to Google Sheets
- PowerPoint presentations to Google Slides

### Jump to Drive from Yazi

Configure a default Drive upload folder once, then use Yazi commands to:

- upload files into that Drive folder
- jump to the matching local Drive folder
- open the Drive folder in your browser

This is useful when you keep a synced or mounted Drive folder on your machine
and want Yazi to be the place where you manage those files.

## Requirements

You need:

- [Yazi](https://github.com/sxyazi/yazi) v25.2.7 or newer. The in-Yazi upload
  conflict dialog requires Yazi's modal child API.
- [`jq`](https://github.com/jqlang/jq)
- One Google Drive CLI:
  - [`googleworkspace-cli`](https://github.com/googleworkspace/cli), which
    provides `gws`
  - [`gogcli`](https://github.com/openclaw/gogcli), which provides `gog`

Authenticate your chosen Drive CLI before using upload or folder-resolution
features.

On Linux, install `xdg-open` or `gio` so the plugin can open Drive URLs.

On WSL or custom desktop setups, set `url_opener` if you want a specific command
such as `wslview`.

## Install

### With `ya pkg`

```sh
ya pkg add gormanity/google-workspace
```

### Manually

```sh
git clone https://github.com/gormanity/google-workspace.yazi.git \
  "${YAZI_CONFIG_HOME:-$HOME/.config/yazi}/plugins/google-workspace.yazi"
```

## Quick start

This is the smallest useful setup.

### 1. Add the plugin setup

Add this to `~/.config/yazi/init.lua`:

```lua
require("google-workspace"):setup()
```

Keep this line even if you do not need custom options. The setup call writes the
helper scripts used by the opener and plugin commands.

### 2. Add the opener

Add this to `~/.config/yazi/yazi.toml`:

```toml
[opener]
google_workspace = [
  { run = '${YAZI_CONFIG_HOME:-$HOME/.config/yazi}/plugins/google-workspace.yazi/open "$@"', desc = "Google Workspace", orphan = true },
]
```

### 3. Choose which files use the opener

Add opener rules in `~/.config/yazi/yazi.toml`:

```toml
[open]
prepend_rules = [
  # Google Drive shortcut files
  { name = "*.gdoc", use = "google_workspace" },
  { name = "*.gsheet", use = "google_workspace" },
  { name = "*.gslides", use = "google_workspace" },
  { name = "*.gdraw", use = "google_workspace" },
  { name = "*.gform", use = "google_workspace" },
  { name = "*.gmap", use = "google_workspace" },
  { name = "*.gsite", use = "google_workspace" },
  { name = "*.glink", use = "google_workspace" },

  # Common local files you may want to upload to Drive
  { name = "*.doc", use = "google_workspace" },
  { name = "*.docx", use = "google_workspace" },
  { name = "*.xls", use = "google_workspace" },
  { name = "*.xlsx", use = "google_workspace" },
  { name = "*.ppt", use = "google_workspace" },
  { name = "*.pptx", use = "google_workspace" },
  { name = "*.pdf", use = "google_workspace" },
]
```

### 4. Add useful keybindings

Add these to `~/.config/yazi/keymap.toml`:

```toml
[[mgr.prepend_keymap]]
on   = [ "u", "g" ]
run  = "plugin google-workspace upload"
desc = "Upload to Google Drive"

[[mgr.prepend_keymap]]
on   = [ "g", "d" ]
run  = "plugin google-workspace cd-upload-dir"
desc = "Go to Google Drive upload directory"

[[mgr.prepend_keymap]]
on   = [ "g", "D" ]
run  = "plugin google-workspace open-upload-dir"
desc = "Open Google Drive upload directory"
```

Restart Yazi after changing the config.

## Configure your Drive folder

Most users should configure an upload folder.

```lua
require("google-workspace"):setup({
  upload_dir_id = "<Drive folder ID>",
})
```

`upload_dir_id` is the Google Drive folder where uploaded files should go. If
you do not set it, files upload to your Drive root.

You can find a folder ID from a Google Drive URL:

```text
https://drive.google.com/drive/folders/<Drive folder ID>
```

## Common setups

### macOS with Google Drive for Desktop

```lua
require("google-workspace"):setup({
  upload_dir_id = "<Drive folder ID>",
})
```

On macOS, the plugin can usually find your local "My Drive" folder
automatically.

### Linux, WSL, rclone, or a custom Drive mount

Set `drive_root` to the local folder that corresponds to "My Drive":

```lua
require("google-workspace"):setup({
  upload_dir_id = "<Drive folder ID>",
  drive_root = "$HOME/Drive/My Drive",
})
```

For WSL, you may also want a custom URL opener:

```lua
require("google-workspace"):setup({
  upload_dir_id = "<Drive folder ID>",
  drive_root = "$HOME/Drive/My Drive",
  url_opener = "wslview",
})
```

### Convert Office files to Google Docs, Sheets, and Slides

By default, Office and OpenDocument files upload as regular Drive files.

To convert supported files to native Google Workspace formats:

```lua
require("google-workspace"):setup({
  upload_dir_id = "<Drive folder ID>",
  convert = true,
})
```

For example:

- `.docx` uploads as a Google Doc.
- `.xlsx` uploads as a Google Sheet.
- `.pptx` uploads as a Google Slides presentation.

### Choose a Drive CLI

By default, the plugin automatically uses `gws` if it is installed, then falls
back to `gog`.

To force one backend:

```lua
require("google-workspace"):setup({
  drive_cli = "gws",
})
```

or:

```lua
require("google-workspace"):setup({
  drive_cli = "gog",
})
```

## Usage

### Open Google Drive shortcut files

In Yazi, open any configured Google shortcut file:

- `.gdoc`
- `.gsheet`
- `.gslides`
- `.gdraw`
- `.gform`
- `.gmap`
- `.gsite`
- `.glink`

The plugin reads `.url` from the shortcut when present. For current Drive for
Desktop shortcut files that contain a Drive file ID, it builds the matching
Drive or Google Workspace URL locally, then opens that URL in your browser.

### Upload a local file and open it in the browser

Open a configured local file such as:

- `.docx`
- `.xlsx`
- `.pptx`
- `.pdf`
- an image
- any other regular file matched by your Yazi opener rules

The plugin asks for confirmation, uploads the file to Google Drive, and opens
the resulting Drive URL.

To skip the confirmation prompt:

```lua
require("google-workspace"):setup({
  assume_yes = true,
})
```

### Upload without opening the browser

Use the `upload` plugin command when you want to send files to Drive without
opening them afterward:

```toml
[[mgr.prepend_keymap]]
on   = [ "u", "g" ]
run  = "plugin google-workspace upload"
desc = "Upload to Google Drive"
```

This uploads the selected files, or the hovered file when nothing is selected,
using the defaults from `init.lua`.

### Jump to your Drive upload folder

Use the `cd-upload-dir` plugin command:

```toml
[[mgr.prepend_keymap]]
on   = [ "g", "d" ]
run  = "plugin google-workspace cd-upload-dir"
desc = "Go to Google Drive upload directory"
```

The plugin resolves your configured `upload_dir_id`, maps it to your local Drive
folder, and changes Yazi to that directory.

If `upload_dir_id` is not set, it tries to jump to your local "My Drive" root.

### Open your Drive upload folder in the browser

Use the `open-upload-dir` plugin command:

```toml
[[mgr.prepend_keymap]]
on   = [ "g", "D" ]
run  = "plugin google-workspace open-upload-dir"
desc = "Open Google Drive upload directory"
```

If `upload_dir_id` is set, this opens that Drive folder. Otherwise, it opens
your Drive root.

## File conflicts

When uploading, the plugin checks whether a non-trashed Drive file with the same
name already exists in the upload folder.

The default behavior is to ask what to do.

```lua
require("google-workspace"):setup({
  overwrite = "prompt",
})
```

Available policies:

| Value      | Behavior                                                                                  |
| ---------- | ----------------------------------------------------------------------------------------- |
| `"prompt"` | Ask whether to replace the existing Drive file, upload another same-name file, or cancel. |
| `"always"` | Replace the existing Drive file without asking.                                           |
| `"never"`  | Upload another same-name Drive file without replacing.                                    |
| `"cancel"` | Cancel the upload when a same-name Drive file exists.                                     |

## Configuration reference

All options are optional.

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

| Option          | Default                | Description                                                                                                                    |
| --------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `upload_dir_id` | Drive root             | Drive folder ID to upload files into.                                                                                          |
| `drive_root`    | Auto-detected My Drive | Local path that corresponds to your Google Drive "My Drive" root. Useful on Linux, WSL, rclone mounts, or custom sync folders. |
| `drive_cli`     | `"auto"`               | Drive CLI backend. Use `"auto"`, `"gws"`, or `"gog"`. In auto mode, the plugin tries `gws` first, then `gog`.                  |
| `url_opener`    | System opener          | Command used to open Drive URLs. The URL is passed as the first argument.                                                      |
| `convert`       | `false`                | Convert supported Office and OpenDocument files to native Google Workspace files while uploading.                              |
| `assume_yes`    | `false`                | Skip upload confirmation prompts.                                                                                              |
| `overwrite`     | `"prompt"`             | Conflict behavior for same-name Drive files: `"prompt"`, `"always"`, `"never"`, or `"cancel"`.                                 |

`drive_root` supports absolute paths, `~`, `$HOME`, and `${HOME}`.

## Supported shortcut files

The plugin can open these Google Drive shortcut files:

| Extension  | Opens as        |
| ---------- | --------------- |
| `.gdoc`    | Google Docs     |
| `.gsheet`  | Google Sheets   |
| `.gslides` | Google Slides   |
| `.gdraw`   | Google Drawings |
| `.gform`   | Google Forms    |
| `.gmap`    | Google Maps     |
| `.gsite`   | Google Sites    |
| `.glink`   | Drive link      |

## Supported conversions

Conversion only happens when `convert = true`.

| Type          | Extensions                                                | Converts to   |
| ------------- | --------------------------------------------------------- | ------------- |
| Documents     | `.doc`, `.docx`, `.odt`, `.rtf`                           | Google Docs   |
| Spreadsheets  | `.xls`, `.xlsm`, `.xlsx`, `.ods`, `.xsv`                  | Google Sheets |
| Presentations | `.ppt`, `.pptx`, `.pot`, `.potx`, `.pps`, `.ppsx`, `.odp` | Google Slides |

Other files, such as PDFs and images, upload as regular Drive files.

## Plugin commands

You can bind these commands in `keymap.toml`.

| Command                                   | What it does                                                                                                       |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `plugin google-workspace`                 | Delegates to Yazi's normal open behavior, using your `[open]` and `[opener]` rules.                                |
| `plugin google-workspace upload`          | Uploads selected files, or the hovered file when nothing is selected, without opening the uploaded file afterward. |
| `plugin google-workspace cd-upload-dir`   | Changes Yazi to the local folder that corresponds to your configured Drive upload folder.                          |
| `plugin google-workspace open-upload-dir` | Opens your configured Drive upload folder in the browser.                                                          |

## Opener flags

Most behavior should be configured globally in `init.lua`, but you can override
some behavior for a specific opener rule.

| Flag                     | What it does                                                                        |
| ------------------------ | ----------------------------------------------------------------------------------- |
| `--convert`              | Convert supported Office and OpenDocument files to native Google Workspace formats. |
| `--assume-yes`           | Upload without asking for confirmation.                                             |
| `--overwrite prompt`     | Ask what to do when a same-name Drive file already exists.                          |
| `--overwrite always`     | Replace the same-name Drive file without asking.                                    |
| `--overwrite never`      | Upload another same-name Drive file without replacing.                              |
| `--overwrite cancel`     | Cancel the upload when a same-name Drive file already exists.                       |
| `--upload-dir-id <id>`   | Use a different Drive upload folder for this opener.                                |
| `--drive-cli gws`        | Use `gws` for this opener.                                                          |
| `--drive-cli gog`        | Use `gog` for this opener.                                                          |
| `--url-opener <command>` | Use a specific command to open Drive URLs.                                          |
| `--no-open`              | Upload without opening the uploaded file afterward.                                 |

### Example: convert Word files but not Excel files

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

### Example: always replace same-name Drive files for one opener

```toml
[opener]
google_workspace_replace = [
  { run = '${YAZI_CONFIG_HOME:-$HOME/.config/yazi}/plugins/google-workspace.yazi/open --overwrite always "$@"', desc = "Upload and replace in Drive", orphan = true },
]
```

Direct opener flags apply only to that opener. Plugin commands such as
`plugin google-workspace upload` and `plugin google-workspace cd-upload-dir` use
the options from `init.lua`.

## Troubleshooting

### Uploads fail

Check that:

- `jq` is installed.
- Either `gws` or `gog` is installed.
- Your Drive CLI is authenticated.
- Your account has permission to upload to the configured `upload_dir_id`.

### Browser does not open

On Linux, install `xdg-open` or `gio`.

On WSL, set a URL opener such as:

```lua
require("google-workspace"):setup({
  url_opener = "wslview",
})
```

### `cd-upload-dir` cannot find the local folder

Set `drive_root` to the local folder that maps to your Drive "My Drive" root:

```lua
require("google-workspace"):setup({
  drive_root = "$HOME/Drive/My Drive",
})
```

This is usually needed on Linux, WSL, rclone mounts, and custom Drive sync
folders.

### A same-name file already exists in Drive

Set an overwrite policy:

```lua
require("google-workspace"):setup({
  overwrite = "prompt",
})
```

Use `"always"` to replace, `"never"` to keep both, or `"cancel"` to stop the
upload.

### The plugin cannot find a Drive CLI

Install and authenticate one of the supported Drive CLIs:

- `googleworkspace-cli`, which provides `gws`
- `gogcli`, which provides `gog`

Or explicitly choose the one you want:

```lua
require("google-workspace"):setup({
  drive_cli = "gws",
})
```

## How it works

Yazi uses static opener rules from `yazi.toml`. This plugin provides a helper
opener script plus Yazi plugin commands.

At startup, `require("google-workspace"):setup(...)` writes the generated helper
scripts and configuration. When Yazi opens a matching file, the helper routes
the request back through the plugin when possible so confirmations, errors, and
status messages can appear inside Yazi.

For Google Drive shortcut files, the helper reads `.url` when present or builds
a Drive or Google Workspace URL from the shortcut's `doc_id`.

For regular local files, the helper uploads through `gws` or `gog`, then opens
the returned Drive URL unless the action is upload-only.

## Development

Run the test suite:

```sh
tests/run
```

The tests use fake `gws`, `gog`, and URL opener commands, so they do not touch
Google Drive.

For syntax checks:

```sh
sh -n open resolve-upload-dir
luac -p main.lua helper-scripts.lua
```

When testing from an installed Yazi config, run:

```sh
yazi --debug
```

## License

MIT
