# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
## [1.0.2] - 2024-11-18
### Changed
- Updated pubspec.yaml to explicitly declare supported platforms for better pub.dev analytics

## [1.0.1] - 2024-11-18

### Changed
- Updated README.md with explicit platform support information
- Clarified that Web platform is intentionally not supported due to TCP socket limitations
- Added detailed platform compatibility section in documentation

### Platform Support
- ✅ Android
- ✅ iOS
- ✅ Windows
- ✅ Linux
- ✅ macOS
- ❌ Web (intentionally not supported - requires direct TCP socket access)

### Fixed
- Declared explicit platform support in pubspec.yaml to improve pub.dev analytics
- Improved package metadata for better platform compatibility recognition

### Documentation
- Enhanced README with platform support matrix
- Added explanation for Web platform incompatibility
- Improved changelog format following Keep a Changelog conventions

## [1.0.0] - 2024-11-17

### Added
- **Initial Release** of flutter_zk package for ZKTeco biometric device management
- Comprehensive TCP/IP communication protocol implementation for ZKTeco devices
- Full user management capabilities:
    - Add new users with customizable attributes (name, privilege, password, card, group)
    - Update existing user information
    - Delete users by UID or User ID
    - Retrieve complete user lists from device
- Attendance record management:
    - Fetch attendance logs with date range filtering
    - Sort attendance records (ascending/descending)
    - Parse various attendance record formats (8, 16, and 40-byte formats)
- Device information retrieval:
    - Firmware version
    - Serial number
    - Platform information
    - MAC address
    - Device name
    - Face recognition algorithm version
    - Fingerprint algorithm version
    - Network parameters (IP, subnet mask, gateway)
    - Device time synchronization
- Device control operations:
    - Enable/disable device
    - Restart device
    - Power off device
    - Refresh internal data
    - Unlock connected doors with configurable duration
    - Play pre-recorded voice messages
- Data management functions:
    - Clear all device data (users, fingerprints, attendance)
    - Clear attendance records only
    - Read device capacity information (users, fingerprints, faces, records)
- Connection management:
    - Automatic authentication handling
    - Session management
    - Configurable timeout support
    - Graceful disconnect handling
- Comprehensive error handling with custom exception types:
    - `ZKError` - Base exception class
    - `ZKErrorConnection` - Connection-related errors
    - `ZKErrorResponse` - Device response errors
    - `ZKNetworkError` - Network communication errors
- Full documentation for all public APIs
- Debug logging support for troubleshooting
