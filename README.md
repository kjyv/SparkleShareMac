# SparkleShare Mac

[![Xcode - Build and Analyze](https://github.com/kjyv/SparkleShareMac/actions/workflows/build-analyze-xcode.yml/badge.svg)](https://github.com/kjyv/SparkleShareMac/actions/workflows/build-analyze-xcode.yml)

This is a native implementation of a SparkleShare client for macOS built with SwiftUI. It covers the basic features of https://github.com/hbons/SparkleShare/
As the original C# app is not maintained anymore and building has become more complicated especially on macOS
with Microsoft discontinuing Visual Studio for Mac, this is possibly a more future proof way of syncing SparkleShare repositories on macOS.

It currently does the following:

* Show a menu bar icon with syncing status
* Allow adding existing local paths or remote repos ("projects" in SparkleShare lingo).
* Download changes in regular intervals, currently 5 minutes
* Upload changes whenever local files have changed

Original SparkleShare features not currently supported:

* Dedicated Git LFS support
* Use notifications.sparkleshare.org to pull instantly (which is based on https://github.com/hbons/TrumpetCat/)
* Show recent changes view (but can also be done with pure `git`)
* Invites and Client Side Encryption
* Likely more :) 
