# Spec Delta

## Purpose

Provides native macOS notification banners alongside the floating prompt window so the user is alerted even when they are away from the screen or the window is not visible.

## ADDED Requirements

### Requirement: Notification banner is posted when the prompt appears
The application SHALL post a native macOS `UserNotifications` banner when the daily reflection prompt is displayed, containing a title and body that indicate a log entry is due.

#### Scenario: Notification appears alongside the floating window
- **WHEN** the application launches to prompt the user for a daily log entry
- **THEN** a macOS notification banner is posted with a title indicating a daily reflection is due

#### Scenario: Notification is not posted when the log is already recorded
- **WHEN** the application launches and determines the current cycle's log has already been recorded
- **THEN** no notification banner is posted and the application exits silently

### Requirement: Clicking the notification brings the prompt window to front
The application SHALL handle notification interaction so that clicking the notification banner or its entry in Notification Center brings the floating prompt window to the foreground and activates the application.

#### Scenario: User clicks the notification banner
- **WHEN** the user clicks the notification banner or its Notification Center entry
- **THEN** the floating prompt window is brought to the foreground and the application becomes the active app

### Requirement: Notification permission is requested gracefully
The application SHALL request notification authorization on first launch and continue to function without notifications if the user denies permission.

#### Scenario: User grants notification permission
- **WHEN** the application requests notification authorization and the user grants it
- **THEN** subsequent prompts post notification banners alongside the floating window

#### Scenario: User denies notification permission
- **WHEN** the application requests notification authorization and the user denies it
- **THEN** the floating prompt window still appears normally without posting notification banners
