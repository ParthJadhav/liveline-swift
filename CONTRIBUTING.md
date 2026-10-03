# Contributing

Start with the [agent task map](AGENTS.md) and [architecture](Docs/Architecture.md)
to locate the implementation. The [verification matrix](Docs/Development.md)
maps changes to checks and identifies commands that refresh tracked media.

## Quick Start

Run from the repository root with Xcode's command-line tools selected:

```bash
swift test
python3 scripts/storybook_manifest.py validate
scripts/install-xcodegen.sh .build/tools/xcodegen
.build/tools/xcodegen/bin/xcodegen generate --spec Examples/LivelineDemo/project.yml
xcodebuild -project Examples/LivelineDemo/LivelineDemo.xcodeproj -scheme LivelineDemo -destination 'generic/platform=iOS Simulator' build
```

## Project Structure

- `Sources/Liveline`: public Swift package and renderer internals
- `Tests/LivelineTests`: math and behavior tests
- `Examples/LivelineDemo`: iOS app generated with XcodeGen
- `Docs`: API and publishing documentation
- `Media`: demo recording artifacts

Keep the package dependency-free unless a new dependency removes meaningful complexity for app consumers.

## Further Guides

- [Scenario source of truth and generated artifacts](Docs/ScenarioMatrix.md)
- [CI lanes and full versus post-merge checks](Docs/CI.md)
- [Performance measurements](Docs/Performance.md)
- [Release procedure](Docs/Publishing.md)
- [Demo-video commands and asset provenance](remotion/README.md)
