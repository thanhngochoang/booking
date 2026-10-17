# AGENTS.md

Instructions for any coding agent working in this repository (Codex, Gemini CLI, Cursor, Copilot, Claude Code, …).

- **Project guidance**: read `CLAUDE.md`. It applies to every agent, not only Claude: architecture, the Flutter rewrite in `app_flutter/`, the rules to follow (theme, imports, Firebase isolation, money and contact rules), commands, and commit conventions.
- **Skills**: shared skills live in `.agents/skills/<name>/SKILL.md`. Read the one that matches your task before starting it.
- **Handoff log (required)**: at the start of any multi-step task, and when you continue someone else's work, follow `.agents/skills/agent-handoff/SKILL.md`. First run

  ```bash
  python3 .agents/skills/agent-handoff/scripts/handoff.py status
  ```

  to see whether another agent stopped half-way on this branch, then log each step before and after doing it. If you are stopped, the next agent continues from that log.
