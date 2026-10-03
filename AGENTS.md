# Working in Liveline Swift

Start with the task routes below. Paths in the source column are relative to
`Sources/Liveline/` unless stated otherwise. Read [Architecture](Docs/Architecture.md)
for the rendering flow and [Development](Docs/Development.md) for checks,
prerequisites, and output locations. Keep the Swift package dependency-free
unless a dependency removes meaningful complexity for consumers.

| Task | Source entry point | Docs / verification |
| --- | --- | --- |
| Public API or chart family | `LivelineChart.swift`, `LivelineChartAdvancedInitializers.swift`, `LivelineConfiguration.swift` | `Docs/API.md`, `Docs/AdvancedCharts.md`, `Sources/Liveline/Liveline.docc/Liveline.md`; family checklist in Architecture |
| Input normalization | `LivelineChartPreparation.swift`, `LivelineTimedCollections.swift`, `LivelineScalar.swift` | `Tests/LivelineTests/LivelinePreparationTests.swift` |
| Scheduling, state, callbacks | `LivelineChartRuntime.swift`, `LivelineChartViewRuntime.swift`, `LivelineRenderState.swift` | `Tests/LivelineTests/LivelineRuntimeTests.swift` |
| Rendering or layout | `LivelineRenderer.swift`, `LivelineChartCompositor.swift`, relevant family renderer/layout | Renderer smoke tests, family tests, focused visual capture |
| Scrub, hover, scroll, zoom | `LivelineInteractionBuilder.swift`, `LivelineAdvancedInteractionBuilder.swift`, `LivelineScrubInteractionView.swift`, `LivelineScrollPanView.swift`, `LivelineViewportGestures.swift` | Runtime/viewport tests, `Examples/LivelineDemo/UITests`, demo UI suite |
| Dither or performance | `LivelineChartStyle.swift`, `LivelineRendererDither.swift`, `LivelineRenderState.swift` | `Docs/Performance.md`; opt-in benchmark |
| Accessibility / Audio Graph | `LivelineAccessibility.swift`, `LivelineAdvancedAccessibility.swift`, `LivelineAudioGraph.swift`, `LivelineAdvancedAudioGraph.swift` | Accessibility/localization tests, demo UI suite |
| Storybook scenarios | `Examples/LivelineDemo/Resources/storybook-scenarios.json`, `Examples/LivelineDemo/Sources/Storybook*Scenarios.swift` | `Docs/ScenarioMatrix.md`; `python3 scripts/storybook_manifest.py validate` |
| Image export / render CLI | `LivelineImageExport.swift`, `Sources/LivelineRender/RenderOptions.swift`, `Sources/LivelineRender/Command.swift` | Image export tests, `Tests/LivelineRenderTests` |
| CI / release | `.github/workflows/ci.yml`, `visual-parity.yml`, `compatibility.yml` | `Docs/CI.md`, `Docs/Publishing.md`, `scripts/verify-release-ready.sh` |
| Demo video / public media | `remotion/README.md`, `remotion/ADVANCED_PR_DEMO.md` | Development's output-to-producer map |

## Authorities and Search

- Scenario IDs come from `Examples/LivelineDemo/Resources/storybook-scenarios.json`.
  Generate `StorybookScenarioIDs.generated.swift` with the tool's `swift` command
  and the marked ScenarioMatrix table with `markdown`; do not hand-edit them.
- `Examples/LivelineDemo/project.yml` is the demo project authority. Install the
  pinned XcodeGen and invoke its executable as shown in CONTRIBUTING.
- Workflow YAML owns CI behavior; `Docs/CI.md` explains lane selection.
  `scripts/verify-visual-parity.sh` owns accepted parity thresholds and exclusions.
- Current catalog totals use `<!-- catalog:scenarios -->`, `catalog:families`,
  or `catalog:advanced` markers and are validated by the existing manifest tool.
  Historical counts and verification records apply only to their labeled revision.
- Run repo-relative commands from the repository root unless a guide says otherwise.
  Use `rg --files` or `git ls-files` for inventories; search the relevant subtree
  and declaration before reading large files. Narrow or split any truncated read.
  Inspect architecture and callers when the change crosses modules.
