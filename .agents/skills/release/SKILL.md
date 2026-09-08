---
name: release
description: Prepare and publish a ScaleMe version release by validating the version, summarizing commits in Chinese, updating Xcode versions, creating release notes, and—only after separate confirmations—committing, tagging, pushing, and creating or updating the GitHub Release. Use when the user asks to release a version, create a release tag, or update a release description.
---

# Confirmed ScaleMe release

Prepare a reviewable ScaleMe release and preserve a clear approval boundary around every Git or GitHub mutation. Work from the repository root and follow `AGENTS.md` throughout.

## Safety boundary

- Treat the user's initial release request as authorization to inspect and prepare files only.
- Never run `git add`, `git commit`, `git tag`, `git push`, `gh release create`, or `gh release edit` until the applicable proposal has been shown and the user has confirmed it in a subsequent reply.
- Require three independent confirmations: release commit, local tag, and remote publication. A confirmation for one phase does not authorize another.
- Never amend, force-push, overwrite an existing tag, bypass hooks, change remotes, or discard user changes.
- Before preparing a release, inspect all tracked and untracked changes. If unrelated changes exist, stop and ask the user to resolve them separately; do not fold them into a release commit or stash them automatically.
- Before each mutation, repeat the relevant read-only checks. If the proposed paths, branch, tag, remote, notes, or commit changed, show a new proposal and require new confirmation.
- Accept confirmation only from an unambiguous reply such as `确认`, `是`, `提交`, `发布`, `yes`, `y`, or `confirm`, after trimming whitespace and an optional trailing period. Accept cancellation from `取消`, `否`, `no`, `n`, or `cancel`.
- For any other reply, do not mutate state and respond: `您的回复不明确。请回复“确认”继续，或回复“取消”终止。`
- If the user cancels a phase, stop the release workflow and report which operations were not performed. Do not ask again automatically.

## 1. Collect and validate the version

Ask for a version if the user did not provide one. Require exactly three numeric components with no `v` prefix, for example `1.2.0`. Reject prerelease/build suffixes unless the user explicitly changes the project's release convention.

Run read-only preflight checks:

```sh
git status --short --branch
git diff --cached
git diff
git ls-files --others --exclude-standard
git branch --show-current
git remote get-url origin
git tag --list "VERSION"
git ls-remote --tags origin "refs/tags/VERSION"
```

Confirm that:

- the current branch is the branch the user intends to release;
- neither the local nor remote `VERSION` tag exists;
- `origin` is the intended GitHub repository;
- GitHub CLI authentication is available before proposing remote publication;
- release preparation will not overwrite unrelated working-tree changes.

Network checks may require approval from the execution environment, but they are not release authorization.

## 2. Build the change summary

Find the previous version tag with `git describe --tags --abbrev=0`. If none exists, use all commits reachable from `HEAD`; otherwise use `LAST_TAG..HEAD`. Inspect non-merge commit subjects and bodies:

```sh
git log --no-merges --format='%H%x09%s%x09%an%n%b' RANGE
```

Classify changes by Conventional Commit prefix and meaning:

- `feat` or a clearly user-visible addition: `✨ 特性`
- `fix` or a corrected defect/regression: `🐛 问题修复`
- `docs`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `style`, release engineering, and other maintenance: `📋 其他`

Translate and synthesize the history into concise, user-facing Chinese. Merge duplicates, omit internal implementation trivia that has no release value, and do not paste raw commit messages. Keep claims consistent with `AGENTS.md`: distinguish fixture-backed support from hardware verification and avoid medical claims.

## 3. Prepare release files

Create `release/VERSION.md` with this stable shape, using `- 无` for empty sections:

```markdown
# VERSION Release Notes

## ✨ 特性
- 中文发布要点

## 🐛 问题修复
- 无

## 📋 其他
- 中文发布要点
```

Update every active `MARKETING_VERSION` assignment in `ScaleMe.xcodeproj/project.pbxproj` to `VERSION`, keeping the main app and widget aligned across configurations. Do not change `CURRENT_PROJECT_VERSION` unless the user explicitly requested a build-number change; if requested, validate it as a positive integer and update every active assignment consistently.

Do not hand-edit unrelated project-file sections. After editing, verify exact assignments with `rg`, inspect the full diff, run `git diff --check`, and ensure only the intended release paths changed.

## 4. Propose and create the release commit

The release commit is also governed by `../commit/SKILL.md`; read it and follow its complete inspection, verification-choice, and confirmation rules. The message must use this form and accurately cover the prepared files:

```text
release: VERSION

- update the ScaleMe marketing version to VERSION
- add Chinese release notes for VERSION
```

If a requested build-number change or another authorized release file is included, adjust the English bullets to match. Before the commit-skill proposal, separately show the complete list of files that the release will commit. Do not proceed until the commit skill receives its own valid choice in a later user reply.

After a successful commit, require a clean working tree. Record the release commit hash for the tag proposal.

## 5. Propose and create the local tag

Use a lightweight tag named exactly `VERSION` without a `v` prefix. Show:

```text
=== 需要确认创建标签 ===

本操作将在发布提交 COMMIT 上创建 Git 标签：VERSION

确认创建该标签吗？请回复“确认”继续，或回复“取消”终止。
```

After confirmation, recheck that `HEAD` is `COMMIT`, the worktree is clean, and the tag is still absent locally and remotely. Then run `git tag VERSION` and verify `git rev-parse VERSION^{commit}` equals `COMMIT`. Stop on any mismatch or failure.

## 6. Propose and publish remotely

Inspect `.github/workflows/` to determine whether a tag workflow creates the GitHub Release and which assets it is expected to attach. Confirm `release/VERSION.md` exists and prepare its GitHub body by removing only the first H1 and following leading blank lines:

```sh
awk 'NR == 1 && /^# / { next } NF { started = 1 } started { print }' release/VERSION.md
```

Show the current branch, exact commit, tag, release-note path, `origin` URL, whether publication will create or update the GitHub Release, and the expected workflow/assets. Ask:

```text
=== 需要确认发布到远端 ===

本操作将推送当前分支与标签，并使用 release/VERSION.md（移除重复 H1 后）创建或更新 GitHub Release。

确认发布吗？请回复“确认”继续，或回复“取消”终止。
```

After confirmation, revalidate every displayed value, then push explicitly:

```sh
git push origin CURRENT_BRANCH VERSION
```

If a configured tag workflow creates the Release, wait for that exact workflow run to complete. If it fails or times out, preserve the pushed state, report the run and failure, and stop without creating replacement tags or releases.

If no workflow is configured to create a Release, create it directly as part of the already confirmed publication phase. If the Release exists, update it. In both cases pass the stripped notes through standard input rather than a temporary tracked file:

```sh
awk 'NR == 1 && /^# / { next } NF { started = 1 } started { print }' release/VERSION.md | gh release edit VERSION --notes-file -
```

Use `gh release create VERSION --title VERSION --notes-file -` instead when the Release does not exist. Do not create a draft or prerelease unless the user explicitly asked for one.

Finally run `gh release view VERSION --json tagName,targetCommitish,body,url,assets`. Verify that the body is nonempty and matches the stripped release notes. Verify assets against the configured workflow; if no assets are configured, state that rather than claiming attachments are complete.

## Failure reporting

On failure, state the last successful phase and the exact remaining state: commit hash, whether the local/remote tag exists, whether the branch was pushed, workflow status, and GitHub Release URL when available. Never silently retry a mutating command or compensate with another tag.
