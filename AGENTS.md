# ScaleMe agent instructions

This is the repository entry point for every coding agent, including Codex, Claude Code, GitHub Copilot, and Cursor. Tool-specific instruction files must point here instead of duplicating project rules.

## Product identity

- Chinese product name: **观我**.
- English product name and Xcode project name: **ScaleMe**.
- Product purpose: a privacy-conscious native iOS app for Bluetooth weight and body-composition scales, personal records, and long-term trend analysis.
- Product wording: “观察身体变化，看见自己的健康轨迹。”
- Do not imply medical diagnosis, treatment, or clinical accuracy. Consumer bioelectrical-impedance results are estimates for trend reference only.

## Required development guide

Before inspecting implementation files, proposing code changes, editing, or reviewing this project, read and follow [the dev skill](.agents/skills/dev/SKILL.md) and every reference it marks as relevant to the task. This requirement applies even when your tool does not support skill discovery: open the Markdown files directly.

The dev skill and its references are the canonical source for development constraints. Maintain those rules there; keep this file as the product identity and loading entry point.

## Commit and release routing

- For a Git commit or commit information, use [the commit skill](.agents/skills/commit/SKILL.md). Its explicit confirmation step is mandatory.
- For a version release, release tag, GitHub Release publication, or release description update, use [the release skill](.agents/skills/release/SKILL.md). Its separate commit, tag, and remote-publication confirmations are mandatory.
