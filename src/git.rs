//! Repository discovery, branch names, and working-tree/upstream status.
//! Lookups run synchronously; the Lua wrapper calls them in libuv workers.

use git2::{Branch, Error, ErrorCode, ObjectType, Repository, Status, StatusOptions};
use std::path::Path;

pub(crate) fn branch(directory: &Path) -> Result<Vec<u8>, Error> {
    let repo = Repository::discover(directory)?;
    branch_name(&repo)
}

fn branch_name(repo: &Repository) -> Result<Vec<u8>, Error> {
    let head = repo.head()?;
    if repo.head_detached()? {
        Ok(head.peel(ObjectType::Commit)?.short_id()?.to_vec())
    } else {
        Ok(head.shorthand_bytes().to_vec())
    }
}

/// Caller-owned counts shared with LuaJIT through the C ABI.
#[repr(C)]
#[derive(Default)]
pub struct GitCounts {
    pub tracked: usize,
    pub untracked: usize,
    pub ahead: usize,
    pub behind: usize,
    pub conflicts: usize,
}

pub(crate) fn status(directory: &Path) -> Result<(Vec<u8>, GitCounts), Error> {
    let repo = Repository::discover(directory)?;
    let name = match branch_name(&repo) {
        Ok(name) => name,
        Err(err) if err.code() == ErrorCode::UnbornBranch => repo
            .find_reference("HEAD")?
            .symbolic_target_bytes()
            .and_then(|name| name.strip_prefix(b"refs/heads/"))
            .ok_or(err)?
            .to_vec(),
        Err(err) => return Err(err),
    };
    let mut counts = GitCounts::default();
    let mut options = StatusOptions::new();
    options
        .include_untracked(true)
        .recurse_untracked_dirs(true)
        .include_ignored(false)
        .renames_head_to_index(true)
        .renames_index_to_workdir(true);
    for entry in repo.statuses(Some(&mut options))?.iter() {
        let flags = entry.status();
        // One status entry covers both index and worktree changes to a file.
        // Conflicts take precedence so they never also increase tracked counts.
        if flags.is_conflicted() {
            counts.conflicts += 1;
        } else if flags == Status::WT_NEW {
            counts.untracked += 1;
        } else if flags != Status::CURRENT && !flags.is_ignored() {
            counts.tracked += 1;
        }
    }
    // Missing upstreams (and detached/unborn HEADs) must not hide file counts.
    let upstream = repo
        .head()
        .ok()
        .filter(|head| head.is_branch())
        .and_then(|head| {
            let local = head.target()?;
            let upstream = Branch::wrap(head).upstream().ok()?.get().target()?;
            repo.graph_ahead_behind(local, upstream).ok()
        });
    if let Some((ahead, behind)) = upstream {
        counts.ahead = ahead;
        counts.behind = behind;
    }
    Ok((name, counts))
}
