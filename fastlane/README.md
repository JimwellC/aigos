fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios verify

```sh
[bundle exec] fastlane ios verify
```

Read-only App Store Connect auth check (no upload, no mutation)

### ios test

```sh
[bundle exec] fastlane ios test
```

Run the unit-test suite on a simulator

### ios build

```sh
[bundle exec] fastlane ios build
```

Archive a signed App Store .ipa (no upload)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload a new build to TestFlight (internal testers)

### ios release

```sh
[bundle exec] fastlane ios release
```

Build the binary and push metadata to App Store Connect (does NOT auto-submit)

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Push only the listing metadata (name/subtitle/description/keywords/etc.) — no binary

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
