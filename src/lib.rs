//! This library provides Rust Git discovery to Neovim through LuaJIT FFI.
//! Lua callers use `require('ffi.git').status(dir, callback)` to run lookups in
//! workers. The wrapper owns the C ABI buffers, so Rust allocations stay inside
//! the library.
//!
//! Build with `cargo build --release` before importing the Lua wrapper, and
//! restart Neovim after building or replacing the library.

mod git;

pub use git::GitCounts;

use std::ffi::{CStr, c_char};
use std::panic::catch_unwind;
use std::path::Path;

const LOOKUP_FAILED: i32 = -1;
const BUFFER_TOO_SMALL: i32 = -2;
const PANICKED: i32 = -3;

fn filesystem_path(path: &CStr) -> Result<&Path, git2::Error> {
    #[cfg(unix)]
    {
        use std::os::unix::ffi::OsStrExt;
        Ok(Path::new(std::ffi::OsStr::from_bytes(path.to_bytes())))
    }
    #[cfg(not(unix))]
    {
        path.to_str()
            .map(Path::new)
            .map_err(|err| git2::Error::from_str(&err.to_string()))
    }
}

/// Writes a branch name or unique detached commit abbreviation using core.abbrev
/// (default seven digits). Returns its byte length, -1 on lookup/argument failure,
/// -2 when the buffer is too small, or -3 on a caught Rust panic. Unborn HEAD is unavailable.
/// Repository discovery starts at `path` and searches its parents.
/// `capacity` includes the NUL terminator. Output is NUL-terminated only on success;
/// discard output on failure.
///
/// # Safety
/// `path` must point to a readable NUL-terminated filesystem path.
/// Unix accepts raw path bytes; other targets require UTF-8.
/// `out` must point to `capacity` writable bytes. The regions must not overlap,
/// and callers must keep them valid throughout the call. Null pointers are rejected.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ffi_git_branch(
    path: *const c_char,
    out: *mut c_char,
    capacity: usize,
) -> i32 {
    if path.is_null() || out.is_null() {
        return LOOKUP_FAILED;
    }
    catch_unwind(|| {
        let path = unsafe { CStr::from_ptr(path) };
        let path = match filesystem_path(path) {
            Ok(path) => path,
            Err(_) => return LOOKUP_FAILED,
        };
        let name = match git::branch(path) {
            Ok(name) => name,
            Err(_) => return LOOKUP_FAILED,
        };
        if name.len() >= capacity || name.len() > i32::MAX as usize {
            return BUFFER_TOO_SMALL;
        }
        unsafe {
            std::ptr::copy_nonoverlapping(name.as_ptr(), out.cast::<u8>(), name.len());
            out.add(name.len()).write(0);
        }
        name.len() as i32
    })
    .unwrap_or(PANICKED)
}

/// Writes the branch name and repository-wide file/upstream counts. Return codes
/// and branch buffer rules match `ffi_git_branch`. Unborn branches are supported.
/// Ahead/behind are zero without a usable upstream; this never fetches remotes.
/// Both outputs are written only on success and must be discarded on failure.
///
/// # Safety
/// `path`, `out`, and `capacity` follow `ffi_git_branch`'s requirements.
/// `counts` must point to writable, aligned storage for one `GitCounts`.
/// All three regions must be non-overlapping and valid throughout the call.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ffi_git_status(
    path: *const c_char,
    out: *mut c_char,
    capacity: usize,
    counts: *mut GitCounts,
) -> i32 {
    if path.is_null() || out.is_null() || counts.is_null() {
        return LOOKUP_FAILED;
    }
    catch_unwind(|| {
        let path = unsafe { CStr::from_ptr(path) };
        let path = match filesystem_path(path) {
            Ok(path) => path,
            Err(_) => return LOOKUP_FAILED,
        };
        let (name, status) = match git::status(path) {
            Ok(status) => status,
            Err(_) => return LOOKUP_FAILED,
        };
        if name.len() >= capacity || name.len() > i32::MAX as usize {
            return BUFFER_TOO_SMALL;
        }
        unsafe {
            std::ptr::copy_nonoverlapping(name.as_ptr(), out.cast::<u8>(), name.len());
            out.add(name.len()).write(0);
            counts.write(status);
        }
        name.len() as i32
    })
    .unwrap_or(PANICKED)
}
