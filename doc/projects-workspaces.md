# Projects and workspaces

Native Lua implementation; no additional plugins. All lists use `better_select`
(fuzzy filtering, cancellation, and file previews). A workspace is a Neovim tab
with a name, working directory, split layout, and buffer membership. `<leader>pp`
opens a known project in its existing workspace or creates one, then offers files.
`<leader><Tab>.` returns to any open workspace, keeping its windows and cursor positions.
The tabline displays workspace numbers and names. Multiple workspaces may use the
same project; project switching selects the first associated workspace.

Start with `<leader>pa` to add a directory, or `<leader>pD` to discover projects beneath
a directory. Visiting files also remembers roots identified by `.git`, `.hg`,
`.svn`, `.projectile`, or `.nvim-project.json`, or an unversioned build manifest
(Cargo, npm, Go, CMake, Make, or Python). Explicit project markers take precedence
over VCS roots; VCS roots take precedence over nested build manifests. Commands
follow the current file's project, using the workspace root for empty and special
buffers. Symlink aliases are canonicalized.
Removing a known project only forgets its registry entry; it never deletes files.

## Key notation

`<leader>` is the configured leader key, which defaults to `<Space>` in this
configuration. Key sequences are written in Vim notation: `<leader>pp` means
press the leader key, then `p`, then `p`. `<Tab>` denotes the Tab key. The mappings
below operate in Normal mode; a number before a sequence supplies a count.

## Workspace bindings

All keys in this table follow `<leader><Tab>`.

| Key | Action |
| --- | --- |
| `<Tab>` | Display workspace numbers and names |
| `.` | Pick an open workspace |
| `` ` `` | Switch back to the previous workspace |
| `n` / `N` | New workspace / prompt for its name |
| `l` | Load a saved workspace into a new tab |
| `s` | Save this workspace under a chosen name |
| `d` | Close this workspace and delete its exclusive buffers |
| `D` | Delete a saved workspace snapshot |
| `r` | Rename this workspace |
| `x` | Clear the session to one empty workspace |
| `R` | Replace the session with the last exit snapshot |
| `[` / `]` | Previous / next workspace, wrapping |
| `1`–`9` / `0` | Workspace by number / final workspace |

`<M-1>`–`<M-9>` and `<M-0>` also switch workspaces (`M` denotes Alt/Meta).
`<C-t>` creates one. Counts select alternate actions:

- `2<leader><Tab>n` / `2<leader><Tab>N`: clone the layout, sharing buffers and unsaved edits / name the clone.
- `2<leader><Tab>s` / `2<leader><Tab>l`: save without prompting / reload the current saved workspace.
- `2<leader><Tab>d`: select another workspace to close.
- Counts on `[` / `]`: move multiple workspaces; a count on `.` selects that workspace number.
- `2<leader>pp`: switch without the file picker; `2<leader>pC`: edit the repeated command.

`<leader>,` and `<leader>bb` select only buffers visited in the current workspace.
Neovim's buffer objects remain shared: a file opened in two workspaces has one
editing state, so edits cannot diverge. Native commands such as `:buffers` still
show the global buffer list. Ordinary `:tabnew` tabs are automatically workspaces.

Closing workspaces preserves buffers belonging to another workspace. Destructive
operations refuse to discard modified buffers: save them (`<leader>ps`, `:write`,
`:wall`) or explicitly discard their changes first. Killing a project affects its
buffers across workspaces, matching the scope of the project action.

## Project bindings

All keys in this table follow `<leader>p`.

| Key | Action |
| --- | --- |
| `.` / `>` | Browse this / another project's root directory |
| `!` / `&` | Run a shell command synchronously / asynchronously at the root |
| `a` / `d` | Add / forget a known project |
| `D` | Recursively discover projects below a directory |
| `b` | Pick a project buffer |
| `c` | Compile project |
| `C` | Repeat the last command in this project |
| `e` | Edit project-local configuration |
| `f` / `F` | Find a file in this / another project |
| `g` | Configure project (e.g. CMake configure) |
| `i` | Invalidate the project's file cache |
| `k` | Kill project buffers |
| `o` | Find a sibling file: same-directory files and matching source/test stems |
| `p` | Switch project |
| `r` | Find recently visited project files |
| `R` | Run project in a terminal |
| `s` | Save modified project files |
| `T` | Test project |
| `x` / `X` | Toggle a project scratch split / switch to its scratch buffer |

File enumeration uses Git's tracked and untracked, nonignored files when inside a
Git repository, otherwise a scheduled native filesystem traversal. Deleted files
are excluded. Discovery traverses directories without following symlink loops.
`<leader>pi` refreshes the file cache after external changes. File pickers support
`better_select` previews and sending selected files to quickfix.

Build/configure/test and asynchronous shell commands put output in quickfix;
compiler paths resolve relative to the project. Completion does not switch you
away from another workspace, window, or active picker. `:copen` displays output
later. Run commands use a terminal for interactive input. Commands are prompted before execution and can
be edited; each command type remembers its last edited value during the session.
Build/configure/test/run and repeat save modified project files before execution.
The current `shell` and `shellcmdflag` are used.

## Project-local configuration

`<leader>pe` opens `.nvim-project.json` in the project root. This JSON file
sets command defaults and local editing options:

```json
{
  "configure": "cmake -S . -B build",
  "compile": "cmake --build build",
  "run": "./build/app",
  "test": "ctest --test-dir build",
  "options": { "shiftwidth": 2, "expandtab": true }
}
```

Command defaults also recognize Cargo, npm, Make, CMake, and Go projects. Local
editing options are `shiftwidth`, `tabstop`, `softtabstop`, `expandtab`, `textwidth`,
and `spell`; they apply on buffer entry. Project commands only run through an
explicit menu action. Commands are shell strings, so quote paths as in your shell.

## Persistence

JSON files live under `stdpath('state')/workspaces/`: `projects.json`, `saved.json`,
and `last-session.json`. Writes use a temporary file followed by rename. Workspace
names are JSON keys, never filesystem paths. The session is saved on normal exit,
including `:qa!`; restoring it is explicit with `<leader><Tab>R`. Exiting an empty
session preserves the previous snapshot. A damaged project registry produces a
warning and disables registry writes until repaired, rather than breaking startup
or overwriting the damaged data.

Snapshots preserve buffer membership, nested splits, active window/tab, cursor
views, tab/window-local directories, project roots, scratch text, and unsaved
ordinary-buffer contents. Loading does not write unsaved contents to source files. Existing modified buffers are
protected from replacement. Recovered text is exempt from auto-save until your
next edit; explicit `:write` still saves it. Saved workspaces can be loaded
alongside current work; name collisions receive a numeric suffix. Missing root directories fall
back to the current directory. Snapshots are validated before loading; a failed
restore rolls back staged tabs and buffer contents.

Live terminal processes, plugin runtime objects, and network connections cannot
be serialized. Special buffers restore as text snapshots; commands are never
restarted automatically. The final session saved by an editor process is the
snapshot available to `<leader><Tab>R`.

## Verification

Run these checks from the repository root. The keyboard test requires an attached
terminal; the other commands run headlessly.

```sh
nvim --headless -u NONE -i NONE -l tests/workspaces.lua
nvim --headless -u NONE -i NONE -l tests/workspaces_restart.lua
nvim --headless -u NONE -i NONE -l tests/workspaces_review.lua
nvim --headless -u NONE -i NONE -l tests/better_select.lua
nvim -u NONE -i NONE -c 'luafile tests/workspaces_ui.lua'
```

Tests isolate persistence in temporary directories and cover the entire binding
inventory, project commands, Git ignores, workspace lifecycles, shared/dirty
buffers, nested layouts, restart recovery, and real keyboard-driven picker use.

## Mapping ownership

`lua/keymaps.lua` assigns physical keys with `unique = true`, so existing
bindings are never silently replaced. Project and workspace modules expose
`<Plug>(acme-projects-ACTION)` and `<Plug>(acme-workspaces-ACTION)` mappings.
For example, `<leader>pp` invokes `<Plug>(acme-projects-switch)` and
`<leader><Tab>n` invokes `<Plug>(acme-workspaces-new)`. Counts pass through to
the action. Numbered workspace targets (`0` through `9`) support normal,
insert, and terminal modes. Module setup alone does not assign physical keys.
