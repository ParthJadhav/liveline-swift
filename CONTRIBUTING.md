# Contributing

## Local Checks

```bash
swift test
xcodegen generate --spec Examples/LivelineDemo/project.yml
xcodebuild -project Examples/LivelineDemo/LivelineDemo.xcodeproj -scheme LivelineDemo -destination 'generic/platform=iOS Simulator' build
```

## Project Structure

- `Sources/Liveline`: public Swift package and renderer internals
- `Tests/LivelineTests`: math and behavior tests
- `Examples/LivelineDemo`: iOS app generated with XcodeGen
- `Docs`: API and publishing documentation
- `Media`: demo recording artifacts

Keep the package dependency-free unless a new dependency removes meaningful complexity for app consumers.
