# Spec Delta

## Purpose

Allows the user to configure the daily prompt trigger time instead of being locked to the hardcoded 02:00 AM schedule.

## ADDED Requirements

### Requirement: User can configure the trigger hour and minute
The system SHALL read a user configuration file (`~/.dailylogger.json`) to determine the scheduled trigger hour and minute. If the file does not exist or does not specify a time, the system SHALL default to 02:00 AM.

#### Scenario: Configuration file sets a custom time
- **WHEN** `~/.dailylogger.json` contains `{"hour": 22, "minute": 30}` and the user runs `./setup.sh`
- **THEN** the generated LaunchAgent plist schedules the trigger at 22:30

#### Scenario: Configuration file does not exist
- **WHEN** `~/.dailylogger.json` does not exist and the user runs `./setup.sh`
- **THEN** the generated LaunchAgent plist schedules the trigger at the default time of 02:00

#### Scenario: Configuration file has invalid values
- **WHEN** `~/.dailylogger.json` contains `{"hour": 25, "minute": -1}`
- **THEN** `./setup.sh` reports a validation error and does not install the LaunchAgent with invalid values

### Requirement: Environment variable overrides configuration file
The system SHALL accept a `DAILY_LOGGER_HOUR` and `DAILY_LOGGER_MINUTE` environment variable pair that overrides the values in `~/.dailylogger.json` during setup.

#### Scenario: Environment variable overrides config file
- **WHEN** `~/.dailylogger.json` contains `{"hour": 22, "minute": 0}` and the user runs `DAILY_LOGGER_HOUR=23 DAILY_LOGGER_MINUTE=0 ./setup.sh`
- **THEN** the generated LaunchAgent plist schedules the trigger at 23:00

### Requirement: Setup regenerates the plist from configuration
The `setup.sh` script SHALL generate the installed LaunchAgent plist by substituting the configured hour and minute into the plist template, rather than copying the template verbatim.

#### Scenario: Plist reflects the configured time after setup
- **WHEN** the user configures a trigger time of 23:30 and runs `./setup.sh`
- **THEN** the installed plist at `~/Library/LaunchAgents/com.user.dailylogger.plist` contains `<integer>23</integer>` for Hour and `<integer>30</integer>` for Minute
