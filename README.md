# SparkleShare for macOS

[![Xcode - Build and Analyze](https://github.com/kjyv/SparkleShareMac/actions/workflows/build-analyze-xcode.yml/badge.svg)](https://github.com/kjyv/SparkleShareMac/actions/workflows/build-analyze-xcode.yml)

This is an implementation of a SparkleShare client for macOS built with modern SwiftUI. It covers most of the features of the discontinued [SparkleShare](https://www.sparkleshare.org/). 
As the original C# app is not maintained anymore, this is intended as a modern replacement at least for macOS.

SparkleShare is a set of projects that allows to automatically sync directories to a remote file storage based on git. It can be used e.g. as a private alternative to commercial syncing or for easy project collaboration with version history and safe syncing included.
Please use [Dazzle](https://github.com/hbons/Dazzle) for the initial setup of the git repositories to connect to.   

Related projects are:

* [SparkleShare iOS](https://github.com/kjyv/SparkleShare-iOS)  
* [SparkleShare Dashboard](https://github.com/kjyv/sparkleshare-dashboard)

## Installation

1. Download the latest DMG from the [Releases](https://github.com/kjyv/SparkleShareMac/releases) page
2. Open the DMG and drag SparkleShare-Mac to your Applications folder
3. Since the app is not code-signed, macOS will quarantine it. Remove the quarantine attribute by running:
   ```bash
   xattr -d com.apple.quarantine /Applications/SparkleShare-Mac.app
   ```
4. Launch the app from Applications

## Features

* Menu bar icon with syncing status and progress
* Add existing local paths or clone remote repos (called "projects" in SparkleShare)
* Automatic sync: pulls every 5 minutes and on wake from sleep, pushes on local file changes
  (batched commits with a 5-second timeout after file changed have been detected to reduce
   intermediate commits)
* SSH key management with auto-generated keys
* Error list view (allowing to ignore common errors)
* Launch at login (enabled by default)
* Mobile Deployment: automatically re-deploy [SparkleShare iOS](https://github.com/kjyv/SparkleShare-iOS) to a connected device before the provisioning profile expires

Original SparkleShare features not currently supported:

* Dedicated Git LFS support
* Use notifications.sparkleshare.org to pull instantly when remote changes happened (which is based on https://github.com/hbons/TrumpetCat/)
* Show recent changes view (but can also be done with pure `git`)
* Invites and Client Side Encryption
