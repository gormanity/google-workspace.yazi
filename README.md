# google-workspace.yazi

A Yazi plugin and opener for Google Workspace and Google Drive workflows.

## Features

- Resolve Google Drive shortcut files in local Drive folders and open them in
  the browser
- Upload local files to Drive, then open them in the browser
- Optionally convert Office and OpenDocument files to native Google Workspace
  formats while uploading
- Jump from Yazi to the default Drive upload folder

## Requirements

- Yazi
- One Drive CLI:
  - [`googleworkspace-cli`](https://github.com/googleworkspace/cli), providing
    `gws`
  - [`gogcli`](https://github.com/openclaw/gogcli), providing `gog`
- `jq`
- `python3`

Complete Drive authentication in your chosen CLI before using upload or
folder-resolution workflows.

Platform notes:

- On macOS, the helper scripts use the system `open` and `osascript` commands.
  `cd-upload-dir` can find Google Drive for Desktop's local My Drive folder
  automatically.
- On Linux, install `xdg-open` or `gio` for opening URLs. For notifications and
  upload confirmation dialogs, install `notify-send`, `zenity`, or `kdialog`, or
  use `--assume-yes`.
- On Linux, WSL, or any setup using a custom Drive sync folder or mount,
  configure `--drive-root` if you want `cd-upload-dir` to map Drive folder IDs
  back to local paths.

## Installation

### Using `ya pkg`

```sh
ya pkg add gormanity/google-workspace
```

### Manual Installation

```sh
git clone https://github.com/gormanity/google-workspace.yazi.git \
  ~/.config/yazi/plugins/google-workspace.yazi
```

Make sure the packaged helper scripts are executable:

```sh
chmod +x ~/.config/yazi/plugins/google-workspace.yazi/open
chmod +x ~/.config/yazi/plugins/google-workspace.yazi/resolve-upload-dir
```

## Configuration

### Opener

Add a `google_workspace` opener to `~/.config/yazi/yazi.toml`:

```toml
[opener]
google_workspace = [
  {
    run = '~/.config/yazi/plugins/google-workspace.yazi/open --upload-dir-id "<Drive folder ID>" "$@"',
    desc = "Google Workspace",
    orphan = true,
  },
]
```

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

If `--upload-dir-id` is omitted, uploads go to Drive root.

By default, the plugin uses `gws` when it is installed and falls back to `gog`.
To force one backend, add `--drive-cli gws` or `--drive-cli gog` to the opener
command.

On Linux, WSL, or any setup where the local Drive folder is not in the macOS
Google Drive for Desktop location, add `--drive-root` to the same opener
command. The path should point at the local directory that corresponds to
Drive's My Drive root, whether it comes from Google Drive for Desktop,
`rclone mount`, a FUSE mount, or another sync client:

```toml
[opener]
google_workspace = [
  {
    run = '~/.config/yazi/plugins/google-workspace.yazi/open --drive-root "$HOME/Drive/My Drive" --upload-dir-id "<Drive folder ID>" "$@"',
    desc = "Google Workspace",
    orphan = true,
  },
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
system URL opener.

### Upload Local Files

Use the configured opener on regular local files to upload them to Drive and
open the resulting Drive URL in the browser.

The opener asks for confirmation before uploading unless `--assume-yes` is set.

### Convert Files

Add `--convert` to the opener command to convert supported Office and
OpenDocument files to native Google Workspace files:

- Documents: `.doc`, `.docx`, `.odt`, `.rtf`
- Spreadsheets: `.xls`, `.xlsm`, `.xlsx`, `.ods`, `.xsv`
- Presentations: `.ppt`, `.pptx`, `.pot`, `.potx`, `.pps`, `.ppsx`, `.odp`

By default, Office and OpenDocument files upload as original Drive files. The
same is true for other local files, such as PDFs and images.

```toml
[opener]
google_workspace = [
  {
    run = '~/.config/yazi/plugins/google-workspace.yazi/open --convert --upload-dir-id "<Drive folder ID>" "$@"',
    desc = "Google Workspace",
    orphan = true,
  },
]
```

`.xsv` files always upload as native Google Sheets.

### Navigate to the Upload Folder

Run the bindable command:

```toml
plugin google-workspace cd-upload-dir
```

The plugin reads the `--upload-dir-id` and `--drive-root` values from the
`google_workspace` opener in `yazi.toml`, resolves the Drive folder through
`gws`, maps it to the matching local Drive folder, and navigates Yazi there.

If no upload folder is configured, it navigates to the local My Drive root when
one can be found or configured.

## Opener Options

| Option                 | Description                                                                      |
| ---------------------- | -------------------------------------------------------------------------------- |
| `--upload-dir-id <ID>` | Drive folder ID to upload files into                                             |
| `--drive-root <PATH>`  | Local My Drive root for `cd-upload-dir` on non-macOS or custom sync/mount setups |
| `--drive-cli <CLI>`    | Drive CLI backend: `auto`, `gws`, or `gog`                                       |
| `--convert`            | Convert supported Office and OpenDocument files to native Google Workspace files |
| `--assume-yes`         | Skip the upload confirmation dialog                                              |

## How It Works

1. Yazi dispatches matching files to the static `google_workspace` opener in
   `yazi.toml`.
2. The packaged `open` script opens Google shortcut URLs directly.
3. For regular local files, `open` uploads the file with `gws` or `gog`, then
   opens the returned Drive URL.
4. `plugin google-workspace` without arguments delegates to Yazi's built-in
   `open`, so it uses the same `[open]` and `[opener]` rules.
5. `plugin google-workspace cd-upload-dir` runs `resolve-upload-dir` and emits a
   Yazi `cd` command for the resolved local Drive path.

## Development

Run the lightweight checks after edits:

```sh
sh -n open resolve-upload-dir
luac -p main.lua
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
