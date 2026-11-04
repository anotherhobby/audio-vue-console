# Verified Commands

Record commands that have been verified in this repository.

Format:

- YYYY-MM-DD: `command` - what it checks or does, plus any caveats.

- 2026-11-02: `openspec init --tools claude --profile custom` - created `openspec/` and the twelve
  `openspec-*` skills, with no commands, because the global config (`openspec config list`)
  already sets `delivery: skills` and all twelve workflows. CLI 1.14.3. Regenerate the skills
  with `openspec update`; do not hand-edit them.

- 2026-11-02: `claude mcp add --scope project xcode -- xcrun mcpbridge` - wrote `.mcp.json`, giving
  Claude Code Xcode's MCP tools. Each new session asks once to approve the project server, and
  Xcode may ask to allow the connection. Until Xcode approves the agent, every Xcode tool fails with
  "isn't approved"; call `XcodeOpenWorkspace` on `AudioVueConsole.xcodeproj` first, which is what
  raises the approval. `xcrun mcpbridge run-agent --dry-run claude` prints how Xcode launches its
  own agent.

- 2026-11-03: `cd ConsoleCore && xcrun swift test` - builds the core and runs its Swift Testing
  suite, the boundary tests included. Runs from the package folder, not the root. Add
  `--filter BoundaryTests` to run only the boundaries. The runner prints `Target Platform:
  macos14.0`; that is the test host, not the package's platform.
