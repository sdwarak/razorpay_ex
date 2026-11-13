# Changelog

## [0.2.0] - 2026-11-13

### Breaking changes
- Requires Elixir 1.17+ and Erlang/OTP 27+ (previously Elixir 1.11+), the minimum versions supported by `httpoison` 3.x and `hackney` 4.x
- `httpoison` requirement raised from `~> 1.8 or ~> 2.0` to `~> 3.0`. Applications that pin `httpoison` to 1.x/2.x, or pin `hackney` to 1.x, must upgrade those pins to resolve with this version

### Security
- Upgrade `httpoison` from `~> 2.0` to `~> 3.0`, which moves the underlying HTTP client from `hackney` 1.x to 4.x and clears the advisories reported against `hackney` 1.25.0:
  - `SNYK-HEX-HACKNEY-16877769` / `CVE-2026-47076` - SSRF allowlist bypass via percent-encoded host in `hackney_url:normalize/2`
  - `SNYK-HEX-HACKNEY-17111516` / `CVE-2026-47075` - CRLF injection in query parameters
  - `SNYK-HEX-HACKNEY-16877752` / `CVE-2026-47069` - CRLF injection via cookie `domain`/`path` options
  - `SNYK-HEX-HACKNEY-16877790` / `CVE-2026-47071` - synchronous remote access without a timeout during the SOCKS5 TLS upgrade
- Also picks up the `hackney` 4.9.0 fix for `CVE-2026-115693` (custom `cacerts`/`cacertfile` not restricting trust to the pinned CA)

### Added
- End-to-end HTTP tests that exercise the real HTTPoison/hackney request path (query parameters, JSON bodies, error mapping, connection failures and request timeouts)

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