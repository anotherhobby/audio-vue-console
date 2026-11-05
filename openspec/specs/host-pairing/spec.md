# host-pairing Specification

## Purpose

Lets the app gain a token from a host by the code its panel shows, keep that token for the host, send
it with every request that needs one, and see and revoke the clients paired with the host.

## Requirements

### Requirement: The app pairs by the code on the panel

When connected to a host it is not paired with, the app SHALL offer to pair. Pairing SHALL ask the host
for a code, which the panel shows, take the six digits the user reads off the panel, and send them back
for a token, which the app keeps for that host.

Source: audio-vue `control-service`, "A client pairs by a code on the panel": no other way to gain a
token exists.

#### Scenario: A first pairing

- **WHEN** the user pairs with a host and types the code its panel shows
- **THEN** the app is given a token, keeps it, and shows itself paired with the host

#### Scenario: A code that is not six digits

- **WHEN** the user types anything but six digits as the code
- **THEN** the app says the code is six digits and sends nothing

### Requirement: The app names itself by the Mac's name

When it asks for a code, the app SHALL name itself by the Mac's computer name, cut to the 64 characters
the host allows, so the host's list of clients says which Mac each is.

Source: Decision (maintainer, 2026-11-04).

#### Scenario: Asking for a code

- **WHEN** the app asks a host for a code on a Mac named `Dan's MacBook Pro`
- **THEN** the request names the client `Dan's MacBook Pro`

#### Scenario: A long computer name

- **WHEN** the Mac's computer name is longer than 64 characters
- **THEN** the app sends its first 64 characters

### Requirement: A refused pairing says why

When the host refuses a pairing, the app SHALL tell apart a wrong code, a code no longer showing, a
pairing already under way, a wait before the next pairing, and a panel that is not running, and SHALL
show the host's own reason. It SHALL offer to ask again once the host's wait has passed.

Source: audio-vue `control-service`, "A pairing code is short-lived and cannot be guessed at": a code
lapses after a time and a number of wrong tries, and one pairing runs at a time.

#### Scenario: A wrong code

- **WHEN** the user sends a code the panel is not showing
- **THEN** the app says the code was wrong, with the host's reason, which says how many tries are left
  or that the code was withdrawn

#### Scenario: A code that lapsed

- **WHEN** the user sends a code after it lapsed or was withdrawn
- **THEN** the app says the code is no longer showing, and offers to ask for a new one

#### Scenario: Another pairing under way

- **WHEN** the app asks for a code while another client's code is showing
- **THEN** the app says a pairing is already under way

#### Scenario: Too soon after the last pairing

- **WHEN** the host refuses a new code and says how many seconds to wait
- **THEN** the app says how long to wait, and offers to ask again when that time has passed

#### Scenario: The panel not running

- **WHEN** the host cannot show a code because its panel is not running
- **THEN** the app says the panel must be running to pair

### Requirement: A mistyped code is typed again

After a wrong code, the app SHALL let the user type the code again at once, and SHALL NOT ask for a
new code while its own code still stands on the panel. It SHALL offer a new code once the code has
lapsed or the host says none is showing.

Source: Decision (maintainer, 2026-11-04): typos are common and should not cost a wait; audio-vue
`control-service` lets one code take several wrong tries, and refuses a new code while one stands.

#### Scenario: Typing the code again

- **WHEN** the user sends a wrong code with tries left
- **THEN** the code field is cleared for the code to be typed again, and sending the right code pairs

#### Scenario: Asking while the code stands

- **WHEN** the app's code still stands on the panel after a wrong code
- **THEN** the app does not ask the host for a new code

#### Scenario: After the code lapses

- **WHEN** the code's time has passed
- **THEN** the app offers to ask for a new code

### Requirement: The app keeps one token per host

The app SHALL keep one token for each host it has paired with, across launches and updates of the app,
without asking the user for a password, and readable by the user's account only. Pairing again with a
host SHALL replace its token and revoke the app's earlier client on that host.

Source: Decision (maintainer, 2026-11-04): the Keychain asks an ad-hoc signed app for the login password
after every update (Measured, `pitfalls.md`); audio-vue `control-service` gives each client its own
token.

#### Scenario: An updated app

- **WHEN** the app paired with a host, is updated, and connects to the host again
- **THEN** it is paired, and no password was asked for

#### Scenario: Pairing again

- **WHEN** the app pairs with a host it already holds a token for
- **THEN** it keeps only the new token, and the host lists this app once

### Requirement: Requests carry the host's token

Every request the app sends to a host SHALL carry the token it keeps for that host, except reading the
version and the two pairing requests, which SHALL carry none.

Source: audio-vue `control-service`, "Everything but pairing and the version takes a token".

#### Scenario: Reading the clients

- **WHEN** a paired app reads the host's clients
- **THEN** the request carries the host's token as `Authorization: Bearer`

#### Scenario: Reading the version

- **WHEN** the app reads a host's version
- **THEN** the request carries no token

### Requirement: A refused token means pair again

When a host answers a request with a token by refusing the token, the app SHALL forget that token and
say it must pair with the host again, and SHALL NOT report it as a fault.

Source: `pitfalls.md`: a host store made again, or a revocation from another client, ends a token with
no word to the app.

#### Scenario: A token the host no longer takes

- **WHEN** the host answers a request carrying the app's token with HTTP 401
- **THEN** the app forgets the token, shows itself not paired, and offers to pair again

### Requirement: The app lists the host's paired clients

A paired app SHALL list the clients paired with the host, each by its name and when it was paired, and
SHALL mark which of them is this app.

Source: audio-vue `control-service`, "A paired client can be revoked": a paired client can list the
paired clients.

#### Scenario: Listing

- **WHEN** a paired app shows the host's clients
- **THEN** it lists each by name and pairing date, with this app marked

### Requirement: The app revokes a paired client

A paired app SHALL revoke any client the host lists, after the user confirms it. Revoking this app
itself SHALL forget its token and leave it not paired.

Source: audio-vue `control-service`, "A paired client can be revoked": a lost laptop should cost one
token, and a client can revoke itself.

#### Scenario: Revoking another client

- **WHEN** the user revokes another client and confirms
- **THEN** the host no longer lists it, and this app stays paired

#### Scenario: Revoking this app

- **WHEN** the user revokes this app and confirms
- **THEN** the app forgets its token and shows itself not paired with the host
