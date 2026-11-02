# Agent Decisions Log

Record implementation decisions made by agents.

Format:

- YYYY-MM-DD: Decision. Rationale. Evidence or related files.

- 2026-11-02: OpenSpec delivered as skills only, with no slash commands (maintainer). The two
  overlap heavily and the skills work well. Matches audio-vue's setup.

- 2026-11-02: The app's product statement lives here, in `agent/product.md`, edited only with the
  maintainer's approval. audio-vue keeps the host platform in `host-platform.md` and leaves
  `desktop-app.md` as a pointer. The app is this repository's whole purpose, while the host side
  is still built against in audio-vue, including by its open `settings-schema` and
  `settings-documents` changes.
