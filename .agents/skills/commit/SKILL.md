---
name: commit
description: Review every non-ignored Git change, prepare an English Conventional Commit with a Chinese summary, and let the user choose direct commit or verified commit. Use when the user asks to commit code, create a commit, or prepare/organize commit information. Do not use for push, tag, release publication, or history rewriting unless separately requested.
---

# Confirmed Git commit

Create one reviewable commit from all current non-ignored repository changes. First present a concise proposal without running builds or tests, then let the user choose whether to commit directly or verify before committing.

## Non-negotiable safety boundary

- Never run `git add`, `git commit`, `git reset`, `git restore`, `git checkout`, `git clean`, or another Git command that changes repository state before showing the proposal and receiving a valid choice in a subsequent user reply.
- Do not treat the initial request to commit—even “直接提交”—as the required choice. First show the exact message and summary, then wait.
- Do not run builds or tests while inspecting and preparing the proposal. Run them only after the user chooses the verified-commit option.
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
- For build-number changes, include both the resulting marketing version and build number in the title, for example `chore: bump build to 2 for version 1.1.0`. Read both values from the final Xcode configuration; the Chinese summary must also show the pair as `1.1.0 (2)`.

When the working tree contains multiple kinds of changes, use the type that represents the primary product outcome and describe supporting work in the body. This skill creates one commit containing all non-ignored changes unless the user explicitly requests a split.

## Phase 3: choose the commit path

Use this exact structure and return it as the final response for the proposal turn:

````markdown
=== 请选择提交方式 ===

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

尚未执行编译或测试。

1. 直接提交（不执行编译或测试）
2. 编译并测试，通过后提交
3. 取消

请回复选项序号或对应文字。
````

Do not include a file list in the proposal. The Chinese summary must still disclose generated files, binaries, or potentially sensitive content when present.

- Direct commit: accept `1`, `直接提交`, `提交`, `确认`, `是`, `yes`, `y`, or `confirm`.
- Verified commit: accept `2`, `编译并测试`, `编译测试后提交`, `测试后提交`, or `验证后提交`.
- Cancel: accept `3`, `取消`, `否`, `no`, `n`, or `cancel`.

Match text case-insensitively after trimming whitespace and an optional trailing Chinese or English period.

For any other reply, do not run Git mutations and respond exactly:

> 您的回复不明确。请回复“1”直接提交、“2”编译测试通过后提交，或“3”取消。

If cancelled, do not mutate Git and respond:

> 提交已取消。如需继续，请重新发起提交请求。

## Phase 4: execute the chosen path

Immediately before staging, rerun:

```sh
git status --short
git ls-files --others --exclude-standard
```

Compare the current path/state set with the inspected proposal snapshot. If anything changed, do not stage or commit. Regenerate the proposal and require a new choice.

For direct commit, do not run a build or tests.

For verified commit, run the repository-prescribed compile check and the smallest relevant test set for the change. The user's choice conditionally authorizes the commit, so do not ask for another confirmation after verification. If any check fails, do not stage or commit; report the failure and stop. After successful verification, rerun the status and untracked-file commands above. If the path/state set changed, regenerate the proposal instead of committing.

If unchanged, run from the repository root:

```sh
git add --all
git diff --cached --check
git diff --cached --stat
git commit -m "<confirmed title>" -m "<confirmed bullet body>"
```

The committed title and body must exactly match the proposed `text` block. If the staged diff check or commit fails, report the error in Chinese and stop; do not bypass hooks or retry with destructive options.

After success, run:

```sh
git status --short --branch
git log -1 --oneline --stat
```

Report the commit hash, exact title, summary, and remaining working-tree state in Chinese. Do not push automatically.
