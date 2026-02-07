# Changelog

## 1.1

- Experimental: Added Mobile Deployment for automatic renewal of SparkleShare iOS app (development profiles expire after 7 days)
    - Auto-deploy to connected device when profile is about to expire
    - Shows notification when profile is expiring and device is not connected
- Sync changes after 5-second timeout to reduce intermediate commits
- Allow expanding full error messages in the error list
- Allow ignoring common errors from the error list

## 1.0

- Automatic git sync for monitored directories
- File watcher with background sync on changes
- Pull changes on wake from sleep and on a regular interval
- Clone remote repositories from the app
- SSH key management with auto-generated keys
- Git clone progress shown in the UI
- Parallel directory sync with ordered pull/push
- Error list view with warnings in the status bar
- Editable project paths
- Projects submenu in the status bar menu
- Sync progress and cancel option in the menu
- Launch at login (enabled by default on first launch)
