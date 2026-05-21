# google-workspace.yazi

Open Google Drive workspace shortcut files from Yazi.

Supported shortcut extensions:

- `.gdoc`
- `.gsheet`
- `.gslides`
- `.gdraw`
- `.gform`
- `.gmap`
- `.gsite`
- `.glink`

The `google_workspace` opener delegates to the packaged `open` script, which
reads stored shortcut URLs and opens them with macOS `open`.

Plain local Office files such as `.docx`, `.xlsx`, and `.pptx` require
confirmation before upload. When confirmed, the opener uses `gws` from
`googleworkspace-cli` to upload them to Drive, then opens the returned Drive URL.

By default, Office files are uploaded without conversion. `.xsv` files are
uploaded as native Google Sheets. Use `--convert` to convert supported Office
files to their matching Google Workspace file type.

Requirements for local upload/conversion:

- `googleworkspace-cli`, providing the `gws` executable
- `jq`
- `gws auth login` completed with Drive access

Opener options:

- `--upload-dir-id <ID>`: Drive folder ID to upload files into
- `--assume-yes`: skip the upload confirmation dialog
- `--convert`: convert supported Office files to native Google Workspace files

Example opener configuration:

```toml
[opener]
google_workspace = [
  { run = '~/.config/yazi/plugins/google-workspace.yazi/open --upload-dir-id "<Drive folder ID>" "$@"', desc = "Google Workspace", for = "macos", orphan = true },
]
```

If `--upload-dir-id` is omitted, uploads default to Drive root.

Bindable command:

```toml
[[mgr.prepend_keymap]]
on   = [ "g", "d" ]
run  = "plugin google-workspace cd-upload-dir"
desc = "Go to Google Drive upload directory"
```

This command reads the `--upload-dir-id` value from the `google_workspace`
opener in `yazi.toml`, resolves it through `gws`, maps it to the matching Google
Drive for Desktop folder under `~/Library/CloudStorage`, and navigates Yazi
there. If no upload directory is configured, it navigates to local My Drive root.

Invoking `plugin google-workspace` without arguments delegates to Yazi's built-in
`open` command, so it also uses the configured opener rules in `yazi.toml`.
