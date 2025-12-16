# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-12-16

### Changed

- Refactored the restart strategy to send a message directly to the process. Processes
  should handle any lengthy initialization via `handle_continue/2` and respond to the
  `{TwoFaced, :ack, ref}` message to confirm completion.

## [0.1.0] - 2025-12-15

### Added
- Initial revision
- Two-phase initialization behaviour for OTP processes
- `TwoFaced.start_child/2` function for starting processes under DynamicSupervisor with two-phase initialization
