# Architecture

## Rendering Flow

```text
LivelineChart public initializers
  -> LivelineChartContent / LivelineAdvancedChartContent
  -> LivelineChartPreparer.prepare -> LivelinePreparedChart / semantics
  -> LivelineChartViewRuntime -> LivelineRenderInput
  -> LivelineRenderer -> LivelineChartCompositor + family mark renderers
```

`LivelineChartPreparation.swift` normalizes time-series inputs and prepares chart
semantics. `LivelineTimedCollections.swift` handles ordered samples and
`LivelineScalar.swift` guards invalid scalar inputs. Tests call the same
preparation interface as production.

`LivelineChartRuntime.swift` contains selection reconciliation and
`LivelineMotionPolicy`. The policy resolves pause, Reduce Motion, snapshot time,
and continuous effects. `LivelineChartViewRuntime.swift` chooses static Canvas
or TimelineView scheduling, builds render input, and delivers callbacks outside
drawing. `LivelineRenderState.swift` retains interpolation and layout caches.

`LivelineRenderer.swift` dispatches drawing. `LivelineChartCompositor.swift`
shares Cartesian axes, hover, crosshairs, and active-point overlays. Rendering
is split among `LivelineRenderer*.swift`, `LivelineHierarchyRenderers.swift`,
and `LivelineAdvancedRenderers.swift`; geometry lives in the matching math and
layout modules. `LivelineRendererDither.swift` applies the shared chart treatment.

Interaction snapshots are built separately by `LivelineInteractionBuilder.swift`
and `LivelineAdvancedInteractionBuilder.swift`. The view owns pointer/scrub
sessions, scroll and viewport gestures, and accessibility inspection. Accessibility
and Audio Graph builders have core and advanced modules; they consume chart
semantics without adding work to the normal drawing path.

The canonical configuration stores typed appearance, effects, viewport,
interaction, motion, annotations, formatting, and callback groups in
`LivelineConfiguration.swift`. `LivelineConfigurationCompatibility.swift`
adapts older flat properties and initializers. Deterministic screenshot timing
is supplied through the testing SPI environment.

## Adding a Chart Family

Follow the existing family in the same category, then review these integration points:

1. Typed models/style, chart content, `LivelineChartKind`, and public initializer.
2. Preparation, invalid-input handling, capabilities, range/time semantics, and identity.
3. Geometry/layout and family rendering through the shared compositor where applicable.
4. Scrub/hover snapshot, structured tooltip rows, selection, and viewport behavior.
5. VoiceOver summaries/inspection, Audio Graph, localization, and Dynamic Type.
6. Family, preparation, runtime, invalid-input, and renderer smoke tests.
7. Manifest scenario and Swift definition; regenerate IDs and the ScenarioMatrix table.
8. Candidate visual capture and review using [Chart Quality](ChartQuality.md).
9. API guide, advanced catalog if applicable, curated DocC topics, CHANGELOG, and release notes.

Use [Development](Development.md) to select the relevant checks and
[Publishing](Publishing.md) for complete release acceptance. The older
[remediation plan](CodeQualityRemediation.md) records work and evidence at named
revisions; it is not a current verification checklist.
