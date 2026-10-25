# Spec Delta

## Purpose

Ensures the Daily Logger's scheduled trigger is automatically registered with macOS launchd during setup and provides a diagnostic command to verify the system is healthy.

## ADDED Requirements

### Requirement: Setup automatically registers the LaunchAgent
The setup process SHALL register the LaunchAgent plist with macOS `launchd` so the scheduled trigger is active immediately after setup completes, without requiring the user to run a separate manual command.

#### Scenario: First-time setup activates the schedule
- **WHEN** the user runs `./setup.sh` on a machine where the LaunchAgent is not yet loaded
- **THEN** the LaunchAgent is registered with `launchd` and the scheduled trigger is active

#### Scenario: Re-running setup replaces an existing registration
- **WHEN** the user runs `./setup.sh` on a machine where an older version of the LaunchAgent is already loaded
- **THEN** the previous registration is removed and a new one is loaded with the current configuration

### Requirement: Status diagnostic reports system health
The application SHALL provide a `--status` CLI flag that inspects the health of the trigger system and reports whether the LaunchAgent is loaded, the plist is valid, whether today's log has been recorded, and the paths to recent stdout/stderr log files.

#### Scenario: Status check when system is healthy
- **WHEN** the user runs `DailyLoggerUI --status` and the LaunchAgent is loaded and today's log exists
- **THEN** the output reports the LaunchAgent as loaded, the plist as valid, and the log as recorded, and the process exits with code 0

#### Scenario: Status check when LaunchAgent is not loaded
- **WHEN** the user runs `DailyLoggerUI --status` and the LaunchAgent is not registered with `launchd`
- **THEN** the output reports the LaunchAgent as not loaded and includes the command needed to load it

#### Scenario: Status check when today's log is missing
- **WHEN** the user runs `DailyLoggerUI --status` and no log entry exists for the current logical date
- **THEN** the output reports the log as pending for today
