# Project Knowledge Base Index

Read this first after `.claude/CLAUDE.md`. Use it to find the smallest relevant context for the task.

## Human-authored Reference

Update this section as new human-authored reference files appear.

- `author/README.md`: The only required human-authored file and general reference.

## Agent-maintained Working Context

- `agent/product.md`: **The product statement**: what the app is, why it is native, the
  appliance-and-companion model, calibration, packaging, the Swift quality gate, and what comes
  later. Each claim marked ruled, measured or inferred. Edited only with the maintainer's approval.
  Read before any product or design work.
- `agent/host-contract.md`: What the app relies on from audio-vue's host agent, built or planned:
  the API, pairing and tokens, scenes and commands, settings and their classes, scene rendering. A view
  of audio-vue's specs, which win. Read before building against the API.
- `agent/project-map.md`: Repository structure, main behavior locations, and concise architecture notes.
- `agent/working-notes.md`: Current task notes and recent discoveries worth carrying forward.
- `agent/decisions-log.md`: Implementation decisions made by agents, with rationale.
- `agent/commands.md`: Verified build, test, lint, run, deploy, and diagnostic commands.
- `agent/pitfalls.md`: Known traps, broken assumptions, and recurring failure modes.
- `agent/open-questions.md`: Questions for humans or unresolved project ambiguities.

## Planning

- `openspec/` at the repo root: OpenSpec planning. `specs/` holds the standing requirements,
  `changes/` one folder per change. Driven by the `openspec-*` skills in `.claude/skills/`;
  there are no slash commands. Project rules for its documents go in `openspec/config.yaml`.

## Related Projects

- `../audio-vue` is the host this app controls (Python, runs on the panel's host). It owns the
  host platform: `../audio-vue/.claude/kb/agent/host-platform.md` (the agent, the store, the
  settings schema, what the console's rendering needs, meter mode), and its specs under `openspec/specs/`. Those win
  over this KB on anything host-side. The API contract is the host agent's `/v1/openapi.json`
  (`src/control_service/` in audio-vue).

## Reading Rule

Read only what is relevant. If the task is narrow, one or two files should usually be enough.