# Spec Delta

## MODIFIED Requirements

### Requirement: A run names the output device feeding the panel

Calibrate… SHALL play through the output device chosen for the panel in the Capture page's Input
section, naming it. While none is chosen, Calibrate… SHALL say to choose one there, and the run
SHALL not start.

Source: Recommended. `product.md`, "The model": the app never assumes where a panel runs, so it
cannot know which output feeds it. Decision (maintainer, 2026-11-09): the output is chosen in the
Input section.

#### Scenario: The second run on a panel

- **WHEN** `D10s` is the output chosen for panel `audio-vue`, and Calibrate… is chosen
- **THEN** Calibrate… names `D10s` as the output it plays through

#### Scenario: The device remembered is gone

- **WHEN** the device remembered for a panel is not among this Mac's outputs
- **THEN** Calibrate… says to choose the output in the Input section, and the run cannot start
