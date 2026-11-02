# Project AI Knowledge Base

This repository has a project-local AI knowledge base under `.claude/kb/`. Use it to find and maintain durable project context without overloading this file.

## Agent Start Protocol

When you begin project work in this repository:

1. Read this file first.
2. Read `.claude/kb/README.md` before making project changes.
3. Read only the KB files relevant to the current task. Prefer the index, then the smallest useful file.
4. Update agent-maintained KB files when you learn durable project facts, decisions, recurring commands, pitfalls, or open questions.
5. Never mutate human-authored KB files unless the user explicitly asks you to edit them.

If the user is only asking a general question that does not require project context, do not read or edit the KB.

## Ownership Rules

Human-authored files live under `.claude/kb/author/`.

- These files are source material from project maintainers.
- Agents may read and summarize them.
- Agents must not edit, rewrite, reorganize, or delete them unless explicitly instructed by the user.
- If an agent notices a likely correction or improvement, record a suggestion in `.claude/kb/agent/open-questions.md` or mention it to the user.

Agent-maintained files live under `.claude/kb/agent/`.

- These files are working memory maintained by agents.
- Agents may create and update them when doing project work.
- Keep entries concise, factual, and easy to prune.
- Prefer dated bullets for facts that may age.
- Remove or revise stale notes when new evidence disproves them.
- Before opening or finalizing a pull request, review whether agent-maintained KB updates are needed and mention any changes made.

The shared index lives at `.claude/kb/README.md`.

- Agents may update the index to keep navigation accurate.
- The index should point to the right file for each kind of context.
- The index should stay short enough to read every session.
- When reading the KB index, briefly compare it against filenames under `.claude/kb/author/`. If new human-authored files exist, update only the shared index.

## Authority Order

When instructions or context conflict, follow this order:

1. The user's latest explicit instruction.
2. Repository source, tests, configuration, and runtime behavior.
3. Human-authored KB files under `.claude/kb/author/`.
4. Shared KB index at `.claude/kb/README.md`.
5. Agent-maintained KB files under `.claude/kb/agent/`.
6. General assumptions from prior sessions or model memory.

If a lower-authority source appears to contradict a higher-authority source, follow the higher-authority source and update or flag the lower-authority KB note when appropriate.

## Maintenance Rules

Update the KB when a fact is likely to help future agents. Do not update it for every tiny observation.

Good KB updates include:

- Verified commands and their caveats.
- Stable repository structure or ownership boundaries.
- User preferences that apply to this project.
- User corrections that reveal durable project rules, team workflow, review standards, or recurring agent failure modes.
- Architectural decisions and rationale.
- Repeated failure modes or environment quirks.
- Open questions that block confident future work.

Avoid KB updates for:

- Temporary command output with no future value.
- Speculation without evidence.
- Large pasted logs.
- Duplicates of information already indexed clearly.
- Details that belong in source code, tests, or public documentation instead.
- Personal interaction preferences unless the user explicitly says they are project or team policy.

When preserving a correction, translate it into an action-oriented project rule with rationale or evidence. Prefer "Do not use X for Y because Z" over "The user dislikes X."

If an agent-maintained note appears to describe team policy, record it as a proposal in `.claude/kb/agent/open-questions.md`. Do not move it into `.claude/kb/author/` unless a human maintainer explicitly writes or approves it.

When information changes, update the existing note instead of adding a contradictory new note. If uncertainty matters, preserve it explicitly.

When touching `working-notes.md`, remove stale task notes that no longer help future work.

## Working Style

Use the KB to reduce repeated discovery, not to avoid reading the actual code. Treat source files, tests, and user instructions as higher authority than agent notes. If the KB conflicts with the repository or the user's latest instruction, follow up with the user on how to reconcile the difference and update the agent-maintained KB if appropriate.

Keep the system boring in the best way: small files, clear ownership, short notes, and enough structure that the next agent can land without rummaging through old chat history.
