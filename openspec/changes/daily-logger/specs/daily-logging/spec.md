# Spec Delta

## Purpose

Enables automated daily activity logging by prompting users at scheduled times (or upon waking), capturing reflections via a focused floating UI, and persisting entries to a JSON Lines text file.

## ADDED Requirements

### Requirement: Scheduled and Wake-up Prompting
The system SHALL trigger the daily logger prompt at 02:00 AM daily, or immediately upon machine wake if the computer was asleep at 02:00 AM.

#### Scenario: Machine active at 2:00 AM
- **WHEN** the system clock reaches 02:00 AM and the machine is active
- **THEN** the logger floating prompt window appears centered on screen

#### Scenario: Machine asleep at 2:00 AM
- **WHEN** the machine wakes from sleep after 02:00 AM and no log has been recorded for the day
- **THEN** the logger floating prompt window appears immediately upon user unlock

### Requirement: Swift Floating Window Input
The Swift desktop application SHALL present a focused, floating window prompting "What did you do today?" with a multi-line text input, a Submit button, and keyboard shortcut support.

#### Scenario: Submitting an entry via keyboard shortcut
- **WHEN** the user types their daily summary and presses Command+Enter
- **THEN** the application submits the entry to the backend and dismisses the window

#### Scenario: Submitting an entry via Submit button
- **WHEN** the user clicks the "Save Log" button
- **THEN** the application passes the text to the backend and closes the prompt window

#### Scenario: Window dismissal without logging
- **WHEN** the user clicks the "Dismiss" or "Cancel" button
- **THEN** the window closes without saving an entry

### Requirement: JSON Lines Text File Persistence
The Python CLI backend SHALL append daily activity logs as individual JSON lines to a designated text file database, recording unique id, timestamp, date, and entry text.

#### Scenario: Appending a valid entry
- **WHEN** the Python CLI is invoked with `log --text "Completed daily plan"`
- **THEN** a new single-line JSON record is appended to the text file containing `id`, `timestamp`, `date`, and `entry` fields

#### Scenario: File creation on first write
- **WHEN** the text file database does not exist on first log submission
- **THEN** the backend creates the file and appends the initial JSON line

### Requirement: Query Today's Log Status
The Python CLI backend SHALL provide an interface to determine whether a log entry has already been recorded for the current day cycle.

#### Scenario: Entry already recorded
- **WHEN** the backend is queried with `has-logged` and a log exists for today
- **THEN** the backend exits with code 0 and reports status that today's entry is complete

#### Scenario: No entry recorded yet
- **WHEN** the backend is queried with `has-logged` and no log exists for today
- **THEN** the backend reports status indicating no entry exists for today
