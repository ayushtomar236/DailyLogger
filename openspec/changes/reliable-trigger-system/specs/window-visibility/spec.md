# Spec Delta

## Purpose

Ensures the floating prompt window is visible to the user regardless of which virtual Space or full-screen application they are currently using.

## ADDED Requirements

### Requirement: Prompt window appears on all virtual Spaces
The floating prompt window SHALL be visible on whichever virtual desktop (Space) the user is currently viewing, rather than only appearing on the Space where the process was launched.

#### Scenario: User is on a different Space when prompt triggers
- **WHEN** the application launches on Space 1 but the user is viewing Space 3
- **THEN** the floating prompt window appears on Space 3 (the user's current Space)

### Requirement: Prompt window overlays full-screen applications
The floating prompt window SHALL appear as an auxiliary overlay on top of full-screen applications, so the user is not required to exit full-screen mode to see the prompt.

#### Scenario: User is in a full-screen application when prompt triggers
- **WHEN** the application launches while the user is using a full-screen application (e.g., full-screen Safari or VS Code)
- **THEN** the floating prompt window appears above the full-screen application

### Requirement: Window comes to front unconditionally
The application SHALL bring its window to the front unconditionally upon launch, bypassing macOS activation policies that might suppress it.

#### Scenario: Application activates even when not the frontmost app
- **WHEN** the application is launched by `launchd` while another application is in the foreground
- **THEN** the floating prompt window appears in front of the current foreground application and receives keyboard focus
