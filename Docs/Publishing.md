# Publishing Checklist

## Private Repository

The repository is intended to be published as a private GitHub repository and consumed through Swift Package Manager.

```bash
gh repo create ParthJadhav/liveline-swift --private --source . --push
```

If the remote already exists:

```bash
git remote add origin https://github.com/ParthJadhav/liveline-swift.git
git push -u origin main
```

## Tagging A Release

SwiftPM can consume a branch, but app teams usually prefer version tags.

```bash
git tag 0.1.0
git push origin 0.1.0
```

Then depend on:

```swift
.package(url: "https://github.com/ParthJadhav/liveline-swift.git", from: "0.1.0")
```

## Verification Before Release

```bash
swift test
xcodegen generate --spec Examples/LivelineDemo/project.yml
xcodebuild -project Examples/LivelineDemo/LivelineDemo.xcodeproj -scheme LivelineDemo -destination 'generic/platform=iOS Simulator' build
```

## Access

For private package installs, grant repository read access to each developer, CI bot, or deploy key that needs to resolve the package.
