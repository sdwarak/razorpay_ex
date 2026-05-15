# Changelog

## [0.1.3] - 2026-05-15

### Security
- Fix timing attack vulnerability in webhook signature verification by replacing `==` with constant-time HMAC comparison
- Fix atom table exhaustion vulnerability by replacing `String.to_atom/1` with `String.to_existing_atom/1` on API response keys
- Remove sensitive data leakage (response bodies, error internals) from error messages in HTTP client
- Fix undefined function calls in legacy `Request` module (`Config.get_headers/0`, `Config.get_auth/0`, `Config.api_url/0`)

## [0.1.2] - 2026-02-09

### Fixed
- Bug fix for OAuth function
- Cleaning redundant code

## [0.1.1] - 2026-01-30

### Added
- First release 