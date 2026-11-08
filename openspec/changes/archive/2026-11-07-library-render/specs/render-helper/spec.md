# Spec Delta

## MODIFIED Requirements

### Requirement: Requests are answered one at a time, in order

The app SHALL send the helper one request at a time and SHALL read each answer, with its layers'
bytes, before sending the next. Of the requests waiting, the canvas's SHALL be sent first, then the
library's, then the gallery's thumbnails'.

Source: audio-vue `scene-render`: requests are answered one at a time, in the order sent. Decision
(this change): the library is on screen beside the canvas, and the gallery is not.

#### Scenario: Two requests at once

- **WHEN** the canvas asks for a plate while a thumbnail's render is under way
- **THEN** the plate's request is sent after the thumbnail's answer has been read

#### Scenario: A resize while the library is drawn

- **WHEN** the user resizes a card while library tiles are waiting to be drawn
- **THEN** the resized plate's request is sent before any waiting tile's
