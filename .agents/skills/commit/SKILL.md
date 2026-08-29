---
name: commit
description: Review every non-ignored Git change, prepare an English Conventional Commit with a Chinese summary, require explicit confirmation, and create the commit only after confirmation. Use when the user asks to commit code, create a commit, or prepare/organize commit information. Do not use for push, tag, release publication, or history rewriting unless separately requested.
---

# Confirmed Git commit

Create one reviewable commit from all current non-ignored repository changes. The analysis/proposal and the mutation must occur in separate user-confirmed phases.

## Non-negotiable safety boundary

- Never run `git add`, `git commit`, `git reset`, `git restore`, `git checkout`, `git clean`, or another Git command that changes repository state before showing the complete proposal and receiving an explicit confirmation in a subsequent user reply.
- Do not treat the initial request to commit—even “直接提交”—as confirmation. First show the exact message and file list, then wait.
- Never amend, rebase, push, tag, publish a release, or modify remotes as part of this skill.
- Never discard or rewrite user changes.
- Include all staged, unstaged, deleted, and untracked files that are not ignored by Git. Hidden files receive the same treatment as other files.
- If the repository has no changes, report that and stop without asking for confirmation.

## Phase 1: inspect every change

Run read-only commands from the repository root:

```sh
git status --short --branch
git diff --cached --stat
git diff --cached
git diff --stat
git diff
git ls-files --others --exclude-standard
```

Inspect the contents of every untracked text file and identify binary files by type and size. Respect `.gitignore`; do not invent additional exclusions. Summarize generated files or potentially sensitive content visibly, but do not silently remove any non-ignored path from the proposed commit.

For large diffs, use per-file or summary commands as needed, but the final analysis must still account for every path returned by Git. Distinguish staged, unstaged, deleted, renamed, and untracked states.

## Phase 2: compose the message

Choose one prefix based on the dominant intent:

- `feat:` for user-visible functionality or a substantial new module.
- `fix:` for a defect, crash, incorrect behavior, or regression.
- `chore:` for documentation, refactoring, tests, tooling, assets, configuration, and other maintenance.
- `release: VERSION` only when the user explicitly requests a release or the change clearly prepares the stated version.

Message rules:

- Write the title and body in English.
- For `feat:`, `fix:`, and `chore:`, start the description after the prefix with a lowercase letter.
- Keep the full title concise and preferably within 50 characters.
- Add a blank line after the title.
- Use lowercase English `- ` bullets for concrete change details.
- Prefer specific outcomes over generic phrases such as “update files” or “make changes.”
- Cover the complete change set with the smallest useful number of bullets.

When the working tree contains multiple kinds of changes, use the type that represents the primary product outcome and describe supporting work in the body. This skill creates one commit containing all non-ignored changes unless the user explicitly requests a split.

## Phase 3: mandatory confirmation

Use this exact structure and return it as the final response for the proposal turn:

````markdown
=== 需要确认提交 ===

提交信息：
```text
[type]: [English description]

- [English change detail 1]
- [English change detail 2]
```

变更摘要：
- [中文变更 1]
- [中文变更 2]
- [中文变更 3]

将提交的文件：
- [状态] [文件路径 1]
- [状态] [文件路径 2]
- [状态] [文件路径 3]

确认提交吗？请回复“确认”继续，或回复“取消”终止。
````

List every file explicitly; do not abbreviate with directory globs, counts, or “等.” Use concise Chinese state labels such as `新增`, `修改`, `删除`, `重命名`, or `已暂存` where useful.

Accepted confirmations are `确认`, `是`, `提交`, `确认。`, `是。`, `提交。`, `yes`, `y`, or `confirm`, matched case-insensitively after trimming whitespace.

Accepted cancellations are `取消`, `否`, `取消。`, `否。`, `no`, `n`, or `cancel`.

For any other reply, do not run Git mutations and respond exactly:

> 您的回复不明确。请回复“确认”继续提交，或回复“取消”终止。

If cancelled, do not mutate Git and respond:

> 提交已取消。如需继续，请重新发起提交请求。

## Phase 4: commit only after confirmation

Immediately before staging, rerun:

```sh
git status --short
git ls-files --others --exclude-standard
```

Compare the current path/state set with the confirmed proposal. If anything changed, do not stage or commit. Regenerate the full proposal and require confirmation again.

If unchanged, run from the repository root:

```sh
git add --all
git diff --cached --check
git diff --cached --stat
git commit -m "<confirmed title>" -m "<confirmed bullet body>"
```

The committed title and body must exactly match the confirmed `text` block. If the staged diff check or commit fails, report the error in Chinese and stop; do not bypass hooks or retry with destructive options.

After success, run:

```sh
git status --short --branch
git log -1 --oneline --stat
```

Report the commit hash, exact title, summary, and remaining working-tree state in Chinese. Do not push automatically.
