# Tasks

## 1. The split

- [x] 1.1 Check the delta keeps every behavior of the requirement as it stands in
      `openspec/specs/scene-rendering/spec.md`: the plate alone in the scene's settings, scaled to
      fit (kept); the smallest size that shows the reading, never below the declared minimum
      (ADDED); the backdrop under the plate, else plain ground (ADDED); its six scenarios kept
      whole. Verify: `openspec validate split-library-tile-requirement --strict` passes.

## Workflow follow-up

- Archive the change, then `openspec validate --specs --strict` passes every spec.
