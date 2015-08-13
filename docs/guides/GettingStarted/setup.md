---
layout: docs
title: Getting Started
permalink: /docs/home/
---

Requires at least XCode 6.4 and the iOS 8 SDK or newer. If you would like to run the app
on a device make sure you have the proper Apple Developer credentials.
[CocoaPods](https://cocoapods.org) is required for a few external
dependencies, you can install it with `$ sudo gem install cocoapods`.

Clone, install, and open with:

```
git clone https://github.com/Kitware/arctic-viewer.git
cd Arctic-Viewer
pod install
open -a XCode Tonic-Native.xcworkspace
```

XCode will open, try running the project on a simulator first, simply press
`⌘R`. Running it on a device is a little more tricky. If you don't have the right
Apple Developer credentials for a plugged in device you'll get some popups
or errors about the problem. Sometimes these are automatically resolveable
through XCode, but usually not.
