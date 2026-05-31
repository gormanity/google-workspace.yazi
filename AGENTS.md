# Agent Instructions

This repository is the standalone source for the Yazi plugin
`google-workspace.yazi`. It is a colocated Jujutsu/Git repository; use `jj` by
default for repo operations.

## Change Hygiene

- Keep jj changes atomic. One logical behavior/docs/workflow update per change.
- Before starting a new logical task or follow-up request, run `jj status` and
  `jj log -r '::@'` to confirm the active change boundary.
- Before editing after a user follow-up, explicitly classify the requested work
  as one of: completion of the current change, bug fix to the current change, or
  new logical behavior/docs/workflow. If it is new logical work, run `jj new`
  first.
- If the current change already contains a different logical task, run `jj new`
  before editing.
- If a change grows to include more than one logical task, run `jj split`
  immediately before continuing.
- Do not bundle opportunistic follow-up features into the current change just
  because they touch the same files, share test setup, or were discovered while
  validating the current change.
- Name each non-empty change with `jj describe` as soon as its purpose is clear.
- Do not leave broad mixed changes for later cleanup.
- After pushing any change, monitor GitHub Actions until the pushed commit's CI
  run passes or fails, then report the result.

## Project Scope

Provide a Yazi opener/plugin for Google Workspace and Google Drive workflows.

The plugin should:

- Open Google Drive shortcut files (`.gdoc`, `.gsheet`, `.gslides`, etc.) from
  their embedded Drive URLs.
- Upload local files to Drive using either `gws` from `googleworkspace-cli` or
  `gog` from `gogcli`.
- Convert supported Office and OpenDocument files only when explicitly
  configured.
- Expose bindable commands to upload files, open the upload folder in the
  browser, and navigate Yazi to the configured local Drive upload folder.

## Files And Invariants

- `main.lua`: Yazi plugin entrypoint.
- `helper-scripts.lua`: Lua source installed by `ya pkg`; it contains the shell
  helper bodies that `main.lua` materializes during setup.
- `open`: development copy of the generated executable used by the Yazi
  `[opener]` command.
- `resolve-upload-dir`: development copy of the generated executable used by the
  bindable `cd-upload-dir` plugin command.
- `tests/run`: automated integration test runner using fake Drive CLIs and an
  isolated Yazi config.
- `.github/workflows/test.yml`: GitHub Actions workflow that installs the test
  dependencies and runs `tests/run`.
- `README.md`: user-facing documentation.
- `LICENSE`: MIT license.

`open` and `resolve-upload-dir` must remain executable and in sync with
`helper-scripts.lua`.

## Architecture Decisions

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
  `${YAZI_CONFIG_HOME:-$HOME/.config/yazi}/google-workspace.yazi.env`, writes
  the generated `open` and `resolve-upload-dir` helper scripts into the plugin
  directory, and makes them executable. This is necessary because `ya pkg`
  installs Lua plugin files and docs, but not arbitrary extensionless helper
  scripts.
- `resolve-upload-dir` reads `upload_dir_id` and `drive_root` from plugin setup;
  if absent, it defaults to local My Drive root.
- `open` and `resolve-upload-dir` support either `gws` from
  `googleworkspace-cli` or `gog` from `gogcli`; `drive_cli = "auto"` prefers
  `gws` and falls back to `gog`.
- `plugin google-workspace` without arguments should delegate to Yazi's built-in
  `open`, so it also uses `[open]`/`[opener]` from `yazi.toml`.
- `plugin google-workspace upload` should upload the selected files, or the
  hovered file when nothing is selected, without opening the uploaded Drive file
  in the browser and without requiring `[open]` rules.
- `plugin google-workspace open-upload-dir` should open the configured upload
  folder URL in the browser, or Drive root if no upload folder is configured.
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
  overwrite = "prompt",
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
- `overwrite`: same-name upload policy: `prompt`, `always`, `never`, or
  `cancel`. `prompt` asks, `always` replaces, `never` uploads a separate
  same-name file, and `cancel` cancels the upload. Defaults to `prompt`.

If `upload_dir_id` is omitted, uploads go to Drive root.

## Opener Contract

Recommended `yazi.toml` shape:

```toml
[opener]
google_workspace = [
  { run = '${YAZI_CONFIG_HOME:-$HOME/.config/yazi}/plugins/google-workspace.yazi/open "$@"', desc = "Google Workspace", orphan = true },
]
```

## Runtime Dependencies

- Yazi v25.2.7 or newer. The upload conflict dialog uses `Modal:children_add`
  and `Modal:children_remove`.
- One of the following Drive CLIs: `googleworkspace-cli`, providing `gws`, or
  `gogcli`, providing `gog`.
- `jq`.
- A local Drive sync folder or mount for `cd-upload-dir`.

Platform-specific runtime behavior:

- macOS uses `open` for URLs and `osascript` for notifications and upload
  confirmations. The local Google Drive for Desktop root is auto-detected under
  `~/Library/CloudStorage`.
- Linux uses `xdg-open` or `gio` for URLs. `notify-send`, `zenity`, and
  `kdialog` are optional notification/confirmation helpers. Configure
  `drive_root` for local Drive folder or mount navigation.

Drive authentication must be completed in the chosen CLI before
upload/conversion workflows.

## Conversion Policy

- Office files (`.xls`, `.xlsx`, `.docx`, `.pptx`, etc.) upload as original
  Drive files by default.
- Office and OpenDocument conversion only happens when `convert = true` or
  `--convert` is set.

Rationale: automatic conversion of Office files is surprising. The user
specifically decided conversion must be opt-in.

## Validation Commands

When any Markdown file is updated, run Prettier with the user's Neovim Markdown
formatter settings:

```sh
npx --yes prettier --config /Users/jmgorman/.dotfiles/prettier/.prettierrc.yaml --write <markdown-file>
```

Run these after edits:

```sh
tests/run
sh -n open resolve-upload-dir
luac -p main.lua helper-scripts.lua
```

If testing from an installed Yazi config, also run:

```sh
yazi --debug
```

Use `gws --dry-run` for request-shape checks before live uploads.

## Known External Artifacts

During development, two tiny Google Drive test spreadsheets were created:

- `yazi-google-workspace-smoke`
- `yazi-gws-reimplementation`

They were intentionally not deleted by the agent without explicit user approval.
