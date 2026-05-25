# Project Handoff

This repository is the standalone source for the Yazi plugin
`google-workspace.yazi`. It was extracted from the user's dotfiles into:

`~/Code/projects/google-workspace.yazi`

The repository is initialized as a colocated Jujutsu/Git repo. Use `jj` by
default for repo operations.

## Goal

Provide a Yazi opener/plugin for Google Workspace and Google Drive workflows on
macOS.

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
- The upload directory must be configured in only one place: the
  `google_workspace` opener command in `yazi.toml`.
- `resolve-upload-dir` reads `--upload-dir-id` from that opener command in
  `~/.config/yazi/yazi.toml`; if absent, it defaults to local My Drive root.
- `plugin google-workspace` without arguments should delegate to Yazi's built-in
  `open`, so it also uses `[open]`/`[opener]` from `yazi.toml`.
- `plugin google-workspace cd-upload-dir` should navigate to the configured
  upload folder, or My Drive root if no upload folder is configured.

## Opener Contract

Recommended `yazi.toml` shape:

```toml
[opener]
google_workspace = [
  { run = '~/.config/yazi/plugins/google-workspace.yazi/open --upload-dir-id "<Drive folder ID>" "$@"', desc = "Google Workspace", for = "macos", orphan = true },
]
```

Supported opener flags:

- `--upload-dir-id <ID>`: Google Drive folder ID for uploads.
- `--convert`: opt into converting supported Office files to native Google
  Workspace files.
- `--assume-yes`: skip the upload confirmation dialog.

If `--upload-dir-id` is omitted, uploads go to Drive root.

## Conversion Policy

- `.xsv` uploads as a native Google Sheet by default.
- Office files (`.xls`, `.xlsx`, `.docx`, `.pptx`, etc.) upload as original
  Drive files by default.
- Office conversion only happens when `--convert` is set.

Rationale: automatic conversion of Office files is surprising. The user
specifically decided conversion must be opt-in.

## Dependencies

Runtime dependencies:

- macOS
- Google Drive for Desktop, for local `~/Library/CloudStorage/.../My Drive`
  navigation.
- `googleworkspace-cli`, providing `gws`.
- `jq`.
- `python3`, used by `resolve-upload-dir` to parse `yazi.toml`.
- `plutil`, available on macOS, for reading Google shortcut files.

`gws auth login` must be completed with Drive access before upload/conversion
workflows.

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
