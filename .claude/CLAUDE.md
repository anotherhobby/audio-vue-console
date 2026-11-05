# Project AI Knowledge Base

This repository has a project-local AI knowledge base under `.claude/kb/`. Use it to find and maintain durable project context without overloading this file.

## Agent Start Protocol

When you begin project work in this repository:

1. Read this file first.
2. Read `.claude/kb/README.md` before making project changes.
3. Read only the KB files relevant to the current task. Prefer the index, then the smallest useful file.
4. Update agent-maintained KB files when you learn durable project facts, decisions, recurring commands, or pitfalls. Ask open questions in the moment; add one to `.claude/kb/agent/open-questions.md` only after asking it and proposing the entry.
5. Never mutate human-authored KB files unless the user explicitly asks you to edit them.

If the user is only asking a general question that does not require project context, do not read or edit the KB.

## Ownership Rules

Human-authored files live under `.claude/kb/author/`.

- These files are source material from project maintainers.
- Agents may read and summarize them.
- Agents must not edit, rewrite, reorganize, or delete them unless explicitly instructed by the user.
- If an agent notices a likely correction or improvement, mention it to the user in the moment.

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
- User corrections that reveal durable project rules, workflow, review standards, or recurring agent failure modes.
- Architectural decisions and rationale.
- Repeated failure modes or environment quirks.
- Open questions the user has been asked and has agreed to record.

Avoid KB updates for:

- Temporary command output with no future value.
- Speculation without evidence.
- Large pasted logs.
- Duplicates of information already indexed clearly.
- Details that belong in source code, tests, or public documentation instead.
- Personal interaction preferences unless the user explicitly says they are project policy.

When preserving a correction, translate it into an action-oriented project rule with rationale or evidence. Prefer "Do not use X for Y because Z" over "The user dislikes X."

If an agent-maintained note appears to describe project policy, propose it to the user in the moment. Do not move it into `.claude/kb/author/` unless a human maintainer explicitly writes or approves it.

When information changes, update the existing note instead of adding a contradictory new note. If uncertainty matters, preserve it explicitly.

When touching `working-notes.md`, remove stale task notes that no longer help future work.

## Working Style

Use the KB to reduce repeated discovery, not to avoid reading the actual code. Treat source files, tests, and user instructions as higher authority than agent notes. If the KB conflicts with the repository or the user's latest instruction, follow up with the user on how to reconcile the difference and update the agent-maintained KB if appropriate.

Keep the system boring in the best way: small files, clear ownership, short notes, and enough structure that the next agent can land without rummaging through old chat history.

## Quality Gate

The quality gate exists to make the code better and tighter. A change that satisfies the gate but leaves the code worse defeats its purpose.

Most findings are right, so fix them. Do something else only when you can defend it: the code is honestly better as written, and satisfying the gate would split up something that belongs together or force a workaround that reads worse. Splitting a function into helpers that share all its state, packing parameters into a struct or dictionary only to get under a count, or naming a constant nobody will ever reuse are all workarounds of that kind.

When that happens, stop and raise it with the user in the moment. Show the finding, the code, the change the gate would push you toward, and why that change is worse. Then the user decides whether to bypass the finding or adjust the rule.

- For a size finding, the gate's own `propose` command records the case, and the user approves it. Explain the case to the user as well. Do not just file it.
- For any other finding, nothing can keep it, so ask. Do not work around it, and do not leave it unfixed.
- Never restructure code only to hide it from the gate.

## Host Versions

**Follow the host; nothing is backward until a release.** Neither audio-vue nor this app is released, and the maintainer is the only user. Until the maintainer declares a release:

- The app supports exactly one host API: the saved contract's. A new one replaces it. Write no version ranges, second majors, shims or fallbacks for an older host.
- At the start of project work, regenerate audio-vue's contract (`make openapi` in `../audio-vue`) and diff it, and the settings schema's version, against the saved copy. If nothing the app uses changed, refresh the saved copy and say so in one line. Otherwise read the diff and propose one OpenSpec change that brings the app up to it.
- The app's own stored data has no migrations. A changed format discards the old file; tokens are re-paired.
- Say nothing about versions, compatibility or migrations in chat, plans or proposals. A step only the maintainer or audio-vue can take is listed as a plain next step.
- Record no API or schema version numbers in the KB or specs. Point to where the current one is read instead.
