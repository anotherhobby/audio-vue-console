# Working Notes

Record short-lived but useful task context here. When touching `working-notes.md`, remove stale task notes that no longer help future work.

- 2026-11-02: Recommended first step per `desktop-app.md`: a two-day canvas spike (snap,
  resize, groups by drag and drop) against a stub host.
- 2026-11-02: The Swift quality gate is built: `../claude-qualty-gate` 0.3.0 (commit
  `8c00f86`), with the limits and never-list from `desktop-app.md`. It applies only once the
  installed plugin is updated (`claude plugin update quality-gate@claude-quality-gate`, then
  restart). Every `try?` is a finding (maintainer). Style is swift-format at 4 spaces and 100
  columns unless this repo adds a `.swift-format`. The type check at Stop builds SwiftPM
  packages only, so app logic belongs in packages and the Xcode shell stays thin.
