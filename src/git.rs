//! `branch` searches a directory and its parents for a Git repository, returning
//! branch-name bytes or a unique commit abbreviation for detached HEAD.
//! Lookup runs synchronously; the Lua wrapper calls it in libuv workers.
//! An unavailable repository or unborn HEAD returns a libgit2 error.

use git2::{Error, ObjectType, Repository};
use std::path::Path;

pub(crate) fn branch(directory: &Path) -> Result<Vec<u8>, Error> {
    let repo = Repository::discover(directory)?;
    let head = repo.head()?;
    if repo.head_detached()? {
        Ok(head.peel(ObjectType::Commit)?.short_id()?.to_vec())
    } else {
        Ok(head.shorthand_bytes().to_vec())
    }
}
