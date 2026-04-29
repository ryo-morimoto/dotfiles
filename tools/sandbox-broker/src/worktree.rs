use std::path::{Path, PathBuf};
use std::process::Command;

/// Resolves the base repository root for a given directory.
/// If the directory is a git worktree, returns the main worktree's root.
/// Otherwise returns the input directory unchanged.
///
/// Uses `git rev-parse --git-common-dir` which returns the shared `.git` directory
/// for both regular repos and worktrees. For a worktree at `/repo-wt/feat-1`,
/// this returns `/repo/.git`, from which we derive the base repo root.
pub fn resolve_base_repo(dir: &Path) -> PathBuf {
    let output = Command::new("git")
        .args(["rev-parse", "--git-common-dir"])
        .current_dir(dir)
        .output();

    let Ok(output) = output else {
        return dir.to_path_buf();
    };

    if !output.status.success() {
        return dir.to_path_buf();
    }

    let common_dir = String::from_utf8_lossy(&output.stdout).trim().to_string();
    let common_path = if Path::new(&common_dir).is_absolute() {
        PathBuf::from(&common_dir)
    } else {
        dir.join(&common_dir)
    };

    // .git/worktrees/<name> → strip to .git, then parent is repo root
    // For a regular repo, common_dir is just `.git` → parent is repo root
    match common_path.canonicalize() {
        Ok(canonical) => {
            if canonical.file_name().map(|n| n == ".git").unwrap_or(false) {
                canonical.parent().unwrap_or(dir).to_path_buf()
            } else {
                dir.to_path_buf()
            }
        }
        Err(_) => dir.to_path_buf(),
    }
}

/// Returns all active worktrees for a given repository directory.
pub fn list_worktrees(dir: &Path) -> Vec<PathBuf> {
    let output = Command::new("git")
        .args(["worktree", "list", "--porcelain"])
        .current_dir(dir)
        .output();

    let Ok(output) = output else {
        return vec![];
    };

    if !output.status.success() {
        return vec![];
    }

    String::from_utf8_lossy(&output.stdout)
        .lines()
        .filter_map(|line| line.strip_prefix("worktree "))
        .map(PathBuf::from)
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn resolve_non_git_dir_returns_same() {
        let tmp = TempDir::new().unwrap();
        let result = resolve_base_repo(tmp.path());
        assert_eq!(result, tmp.path());
    }

    #[test]
    fn resolve_regular_repo_returns_same() {
        let tmp = TempDir::new().unwrap();
        Command::new("git")
            .args(["init"])
            .current_dir(tmp.path())
            .output()
            .unwrap();

        let result = resolve_base_repo(tmp.path());
        assert_eq!(result.canonicalize().unwrap(), tmp.path().canonicalize().unwrap());
    }

    #[test]
    fn resolve_worktree_returns_base() {
        let tmp = TempDir::new().unwrap();
        let base = tmp.path().join("base");
        let wt = tmp.path().join("wt-feat");

        std::fs::create_dir_all(&base).unwrap();
        Command::new("git")
            .args(["init"])
            .current_dir(&base)
            .output()
            .unwrap();
        Command::new("git")
            .args(["commit", "--allow-empty", "-m", "init"])
            .current_dir(&base)
            .output()
            .unwrap();
        Command::new("git")
            .args(["worktree", "add", wt.to_str().unwrap(), "-b", "feat"])
            .current_dir(&base)
            .output()
            .unwrap();

        let result = resolve_base_repo(&wt);
        assert_eq!(
            result.canonicalize().unwrap(),
            base.canonicalize().unwrap()
        );
    }

    #[test]
    fn list_worktrees_includes_all() {
        let tmp = TempDir::new().unwrap();
        let base = tmp.path().join("base");
        let wt = tmp.path().join("wt-feat");

        std::fs::create_dir_all(&base).unwrap();
        Command::new("git")
            .args(["init"])
            .current_dir(&base)
            .output()
            .unwrap();
        Command::new("git")
            .args(["commit", "--allow-empty", "-m", "init"])
            .current_dir(&base)
            .output()
            .unwrap();
        Command::new("git")
            .args(["worktree", "add", wt.to_str().unwrap(), "-b", "feat"])
            .current_dir(&base)
            .output()
            .unwrap();

        let trees = list_worktrees(&base);
        assert_eq!(trees.len(), 2);
        assert!(trees.iter().any(|t| t.canonicalize().unwrap() == base.canonicalize().unwrap()));
        assert!(trees.iter().any(|t| t.canonicalize().unwrap() == wt.canonicalize().unwrap()));
    }
}
