# Projects and workspaces

Native Lua implementation; no additional plugins. All lists use `better_select`
(fuzzy filtering, cancellation, and file previews). A workspace is a Neovim tab
with a name, working directory, split layout, and buffer membership. `SPC p p`
opens a known project in its existing workspace or creates one, then offers files.
`SPC TAB .` returns to any open workspace, keeping its windows and cursor positions.
The tabline displays workspace numbers and names. Multiple workspaces may use the
same project; project switching selects the first associated workspace.

Start with `SPC p a` to add a directory, or `SPC p D` to discover projects beneath
a directory. Visiting files also remembers roots identified by `.git`, `.hg`,
`.svn`, `.projectile`, or `.nvim-project.json`, or an unversioned build manifest
(Cargo, npm, Go, CMake, Make, or Python). Explicit project markers take precedence
over VCS roots; VCS roots take precedence over nested build manifests. Commands
follow the current file's project, using the workspace root for empty and special
buffers. Symlink aliases are canonicalized.
Removing a known project only forgets its registry entry; it never deletes files.

## Workspace bindings

All keys in this table follow `SPC TAB`.

| Key | Action |
| --- | --- |
| `TAB` | Display workspace numbers and names |
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

`Alt-1`–`Alt-9` and `Alt-0` also switch workspaces. `Ctrl-t` creates one.
Neovim counts provide Doom's prefix-argument variants:

- `2 SPC TAB n` / `2 SPC TAB N`: clone the layout, sharing buffers and unsaved edits / name the clone.
- `2 SPC TAB s` / `2 SPC TAB l`: save without prompting / reload the current saved workspace.
- `2 SPC TAB d`: select another workspace to close.
- Counts on `[` / `]`: move multiple workspaces; a count on `.` selects that workspace number.
- `2 SPC p p`: switch without the file picker; `2 SPC p C`: edit the repeated command.

These use Vim counts rather than Emacs's `SPC u` universal argument.
`SPC ,` and `SPC b b` select only buffers visited in the current workspace.
Neovim's buffer objects remain shared: a file opened in two workspaces has one
editing state, so edits cannot diverge. Native commands such as `:buffers` still
show the global buffer list. Ordinary `:tabnew` tabs are automatically workspaces.

Closing workspaces preserves buffers belonging to another workspace. Destructive
operations refuse to discard modified buffers: save them (`SPC p s`, `:write`,
`:wall`) or explicitly discard their changes first. Killing a project affects its
buffers across workspaces, matching the scope of the project action.

## Project bindings

All keys in this table follow `SPC p`.

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
`SPC p i` refreshes the file cache after external changes. File pickers support
`better_select` previews and sending selected files to quickfix.

Build/configure/test and asynchronous shell commands put output in quickfix;
compiler paths resolve relative to the project. Completion does not switch you
away from another workspace, window, or active picker. `:copen` displays output later. Run commands use a
terminal for interactive input. Commands are prompted before execution and can
be edited; each command type remembers its last edited value during the session.
Build/configure/test/run and repeat save modified project files before execution.
The current `shell` and `shellcmdflag` are used.

## Project-local configuration

`SPC p e` opens `.nvim-project.json`, the Neovim equivalent of Doom's `.dir-locals`
entry. It is data, not Emacs Lisp or automatically executed Lua:

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
including `:qa!`; restoring it is explicit with `SPC TAB R`. Exiting an empty
session preserves the previous snapshot. A damaged project registry produces a
warning and disables registry writes until repaired, rather than breaking startup
or overwriting the damaged data.

Snapshots preserve buffer membership, nested splits, active window/tab, cursor
views, tab/window-local directories, project roots, scratch text, and unsaved ordinary-buffer contents. Loading
does not write unsaved contents to source files. Existing modified buffers are
protected from replacement. Recovered text is exempt from auto-save until your
next edit; explicit `:write` still saves it. Saved workspaces can be loaded alongside current
work; name collisions receive a numeric suffix. Missing root directories fall
back to the current directory. Snapshots are validated before loading; a failed
restore rolls back staged tabs and buffer contents.

Live terminal processes, plugin runtime objects, and network connections cannot
be serialized. Special buffers restore as text snapshots; commands are never
restarted automatically. The final session saved by an editor process is the
snapshot available to `SPC TAB R`.

## Parity reference and verification

The binding inventory follows Doom's default `workspace` and `project` prefix
maps in [config/default/+evil-bindings.el](https://github.com/doomemacs/modules/blob/main/modules/config/default/%2Bevil-bindings.el).
Emacs-specific commands use the native equivalents described above.

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
