# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

The guidance is shared with every other coding agent and lives in [AGENTS.md](AGENTS.md); it is imported
here unchanged:

@AGENTS.md

Claude Code specifics: the shared skills in `.agents/skills/` are symlinked into `.claude/skills/` so they
load as project skills; add a new shared skill under `.agents/skills/` and link it the same way. The
legacy Android guidance loads from `app/CLAUDE.md` only when you work under `app/`.
