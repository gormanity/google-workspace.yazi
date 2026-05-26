# Project Handoff

This repository is the standalone source for the Yazi plugin
`google-workspace.yazi`. It was extracted from the user's dotfiles into:

`~/Code/projects/google-workspace.yazi`

The repository is initialized as a colocated Jujutsu/Git repo. Use `jj` by
default for repo operations.

## Change Hygiene

- Keep jj changes atomic. One logical behavior/docs/workflow update per change.
- Before starting a new logical task or follow-up request, run `jj status` and
  `jj log -r '::@'` to confirm the active change boundary.
- If the current change already contains a different logical task, run `jj new`
  before editing.
- If a change grows to include more than one logical task, run `jj split`
  immediately before continuing.
- Name each non-empty change with `jj describe` as soon as its purpose is clear.
- Do not leave broad mixed changes for later cleanup.

## Goal

Provide a Yazi opener/plugin for Google Workspace and Google Drive workflows.

The plugin should:

- Open Google Drive shortcut files (`.gdoc`, `.gsheet`, `.gslides`, etc.) from
  their embedded Drive URLs.
- Upload local Office/spreadsheet files to Drive using `gws` from
  `googleworkspace-cli`.
- Convert only when explicitly configured.
- Expose a bindable command to navigate Yazi to the configured Drive upload
  directory.

## Current Files

- `main.lua`: Yazi plugin entrypoint.
- `open`: packaged executable used by the Yazi `[opener]` command.
- `resolve-upload-dir`: packaged executable used by the bindable `cd-upload-dir`
  plugin command.
- `README.md`: current user-facing docs.
- `LICENSE`: MIT license.

`open` and `resolve-upload-dir` must remain executable.

## Important Decisions

- Yazi plugins cannot self-register `[opener]` entries or keybindings.
- Opener behavior belongs in `yazi.toml`, because Yazi `[opener]` entries are
  static shell commands.
- Do not put user config inside the plugin directory. Yazi package-managed
  plugins can detect source divergence as an error.
- User-managed plugin config belongs in `~/.config/yazi/init.lua` via
  `require("google-workspace"):setup({ ... })`.
- The upload directory must be configured in only one place: `upload_dir_id` in
  plugin setup.
- `main.lua` writes setup values to
  `${YAZI_CONFIG_HOME:-$HOME/.config/yazi}/google-workspace.yazi.env`; `open`
  and `resolve-upload-dir` load that generated file.
- `resolve-upload-dir` reads `upload_dir_id` and `drive_root` from plugin setup;
  if absent, it defaults to local My Drive root.
- `open` and `resolve-upload-dir` support either `gws` from
  `googleworkspace-cli` or `gog` from `gogcli`; `drive_cli = "auto"` prefers
  `gws` and falls back to `gog`.
- `plugin google-workspace` without arguments should delegate to Yazi's built-in
  `open`, so it also uses `[open]`/`[opener]` from `yazi.toml`.
- `plugin google-workspace cd-upload-dir` should navigate to the configured
  upload folder, or My Drive root if no upload folder is configured.

## Configuration Contract

Recommended `init.lua` shape:

```lua
require("google-workspace"):setup({
  upload_dir_id = "<Drive folder ID>",
  drive_root = "$HOME/Drive/My Drive",
  drive_cli = "auto",
  url_opener = "wslview",
  convert = false,
  assume_yes = false,
})
```

All setup options are optional.

Supported setup options:

- `upload_dir_id`: Google Drive folder ID for uploads.
- `drive_root`: local My Drive root for `cd-upload-dir` on non-macOS, WSL, or
  custom Drive sync/mount setups.
- `drive_cli`: Drive CLI backend: `auto`, `gws`, or `gog`. Defaults to `auto`.
- `url_opener`: command used to open Drive URLs. It receives the URL as its
  first argument.
- `convert`: opt into converting supported Office files to native Google
  Workspace files.
- `assume_yes`: skip the upload confirmation dialog.

If `upload_dir_id` is omitted, uploads go to Drive root.

## Opener Contract

Recommended `yazi.toml` shape:

```toml
[opener]
google_workspace = [
  {
    run = """
      ${YAZI_CONFIG_HOME:-$HOME/.config/yazi}/plugins/google-workspace.yazi/open \
        "$@"
    """,
    desc = "Google Workspace",
    orphan = true,
  },
]
```

## Conversion Policy

- `.xsv` uploads as a native Google Sheet by default.
- Office files (`.xls`, `.xlsx`, `.docx`, `.pptx`, etc.) upload as original
  Drive files by default.
- Office conversion only happens when `--convert` is set.

Rationale: automatic conversion of Office files is surprising. The user
specifically decided conversion must be opt-in.

## Dependencies

Runtime dependencies:

- Yazi.
- One Drive CLI: `googleworkspace-cli`, providing `gws`, or `gogcli`, providing
  `gog`.
- `jq`.
- `python3`, used to parse Google shortcut files, infer MIME types, and parse
  `yazi.toml`.
- A local Drive sync folder or mount for `cd-upload-dir`.

Platform-specific runtime behavior:

- macOS uses `open` for URLs and `osascript` for notifications and upload
  confirmations. The local Google Drive for Desktop root is auto-detected under
  `~/Library/CloudStorage`.
- Linux uses `xdg-open` or `gio` for URLs. `notify-send`, `zenity`, and
  `kdialog` are optional notification/confirmation helpers. Configure
  `--drive-root` for local Drive folder or mount navigation.

Drive authentication must be completed in the chosen CLI before
upload/conversion workflows.

## Validation Commands

When any Markdown file is updated, run Prettier with the user's Neovim Markdown
formatter settings:

```sh
npx --yes prettier --config /Users/jmgorman/.dotfiles/prettier/.prettierrc.yaml --write <markdown-file>
```

Run these after edits:

```sh
sh -n open resolve-upload-dir
luac -p main.lua
```

If testing from an installed Yazi config, also run:

```sh
yazi --debug
```

Use `gws --dry-run` for request-shape checks before live uploads.

## Known Test Artifacts

During development, two tiny Google Drive test spreadsheets were created:

- `yazi-google-workspace-smoke`
- `yazi-gws-reimplementation`

They were intentionally not deleted by the agent without explicit user approval.
