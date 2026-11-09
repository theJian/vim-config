# Rust native modules

`require('ffi.git')` exposes Rust Git branch discovery as an ordinary Lua
module. Lua owns the public API, library loading, buffers, and libuv worker
scheduling. Rust uses `git2` to discover repositories and exports a small C ABI.
No Rust pointers or Lua objects cross worker boundaries.

## Build and try

From the repository root, with Cargo and a C build toolchain installed:

```sh
cargo build --release
nvim --headless -u NONE -i NONE -l tests/ffi_git.lua
```

The Cargo package is `ffi` and its library is `ffi`: the build produces
`target/release/libffi.dylib` on macOS, `libffi.so` on Linux, or `ffi.dll`
on Windows. `NVIM_NATIVE_LIBRARY` overrides the absolute library path. Importing
`ffi.git` loads the library immediately and raises an error if it is unavailable.
Importing does not compile anything. The loader caches success or failure;
restart Neovim after building or replacing the library.

The release profile disables symbol stripping to avoid the macOS 27 load failure
tracked in [rust-lang/rust#157750](https://github.com/rust-lang/rust/issues/157750).

With this repository on Neovim's runtime path:

```lua
local git = require 'ffi.git'
local queued, err = git.branch(vim.fn.getcwd(), function(branch, lookup_error)
  if lookup_error then
    vim.notify(lookup_error, vim.log.levels.WARN)
    return
  end
  vim.notify('Branch: ' .. branch)
end)
if not queued then
  vim.notify(err, vim.log.levels.WARN)
end
```

`branch(dir, callback)` returns true if queued, or false and a diagnostic when
worker creation or queueing fails. Relative paths resolve against Neovim's current
directory when `branch` is called. Rejected requests do not invoke the callback.
Invalid Lua argument types and paths containing NUL bytes raise an error. Queued requests
invoke the callback on Neovim's main loop with a branch string, or an empty string
and diagnostic on failure. Repository discovery searches parent directories and
supports linked worktrees. Detached HEAD uses libgit2's unique object-ID
abbreviation, starting at `core.abbrev` (default seven digits) and extending when
needed to avoid ambiguity. Unborn HEAD and non-repositories yield lookup failures.

Requests cannot be individually cancelled; slow filesystems can occupy a libuv
worker.

Filesystem paths preserve raw bytes on Unix; other targets accept UTF-8 paths.
Host builds and tests establish platform support; other targets need their own
validation.

## Boundary and integration

`src/git.rs` holds ordinary Rust logic. `src/lib.rs` translates results into the
C ABI. `lua/ffi/loader.lua` resolves the library and checks the Git branch symbol;
`lua/ffi/git.lua` exposes the asynchronous Lua API. The loader retains the
library handle for the module's lifetime. Workers load their own handles.
Rebuild the library after changing native code or its Lua calling contract.

`ffi_git_branch(path, out, capacity)` returns the written byte length,
-1 for lookup or argument failure, -2 for insufficient capacity, or -3 for a
caught Rust panic. The caller owns both buffers and must provide valid,
non-overlapping memory. Successful output is NUL-terminated; capacity includes
that terminator. Output must be discarded on failure. Panics are caught when
Rust uses unwinding; process aborts and invalid foreign pointers cannot be caught.
Lua retries small buffers up to 64 KiB. Diagnostic strings currently distinguish
load/queue failures and native status codes, not individual libgit2 errors.

`lua/better_statusline.lua` requires `ffi.git` for branch requests. The statusline
module caches branch results and bar strings, so redraws use cached data while
lookups run in workers. Missing libraries fail at import, and rejected worker
requests raise errors. There is no Git-command or Gitsigns fallback. The global
statusline shows repository information and editor status: branch, mode, and
cursor position. File information stays in window bars.
Git commands are not required for statusline lookups.

## Verification

```sh
cargo fmt --check
cargo clippy --offline --locked -- -D warnings
cargo build --release --offline --locked
nvim --headless -u NONE -i NONE -l tests/ffi_git.lua
nvim --headless -u NONE -i NONE -l tests/better_statusline.lua
```

The native test creates disposable repositories and exercises worker callbacks,
nested discovery, linked worktrees, unborn and detached HEAD, Unicode names,
concurrent requests, caller-owned buffer limits, invalid arguments, and a missing
library. Git is required for these test fixtures. Offline Cargo commands require
dependencies to be cached already.
