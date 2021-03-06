# Arctic Viewer

A native iOS wrapper and data manager for [Tonic Arctic Viewer](https://github.com/Kitware/arctic-viewer).
For iPhone and iPad, requires iOS 8 or newer.

## Setup

The project depends on three [CocoaPods](https://cocoapods.org/) which are marked in the `Podfile`.
You can quickly install CocoaPods with `$ sudo gem install cocoapods`.

```
$ git clone https://github.com/Kitware/arctic-viewer-ios.git
$ cd arctic-viewer
$ pod install
$ open -a XCode ArcticViewer.xcworkspace
```
Because we're using CocoaPods always make sure you're openeing the `.xcworkspace` and **not** the `.xcodeproj`

## Trying it out

From XCode you can run the project on an iOS Simulator. With a device plugged in,
you can run it on the device itself. Arctic Viewer is also available
[on the App Store](https://itunes.apple.com/us/app/arctic-viewer/id1038452328?mt=8).

## Licensing

**Arctic Viewer** is licensed under [BSD Clause 3](LICENSE).

## Getting Involved

Fork this repository and do great things. At [Kitware](http://www.kitware.com),
we've been contributing to open-source software for 15 years and counting, and
want to make **Arctic Viewer** useful to as many people as possible.
