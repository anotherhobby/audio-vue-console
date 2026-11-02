# Project Knowledge Base Index

Read this first after `.claude/CLAUDE.md`. Use it to find the smallest relevant context for the task.

## Human-authored Reference

Update this section as new human-authored reference files appear.

- `author/README.md`: The only required human-authored file and general reference.

## Agent-maintained Working Context

- `agent/project-map.md`: Repository structure, main behavior locations, and concise architecture notes.
- `agent/working-notes.md`: Current task notes and recent discoveries worth carrying forward.
- `agent/decisions-log.md`: Implementation decisions made by agents, with rationale.
- `agent/commands.md`: Verified build, test, lint, run, deploy, and diagnostic commands.
- `agent/pitfalls.md`: Known traps, broken assumptions, and recurring failure modes.
- `agent/open-questions.md`: Questions for humans or unresolved project ambiguities.

## Related Projects

- `../audio-vue` is the host this app controls (Python, runs on the panel's host). The app's
  product statement is `../audio-vue/.claude/kb/agent/desktop-app.md`; it is owned there, read
  from here, and wins over anything in this KB about what the app is. The API contract is the
  host agent's `/v1/openapi.json` (`src/control_service/` in audio-vue).

## Reading Rule

Read only what is relevant. If the task is narrow, one or two files should usually be enough.