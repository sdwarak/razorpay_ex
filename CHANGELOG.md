# Changelog

## [0.3.0] - 2026-11-13

### Breaking changes
- `RazorpayEx.Request.raw_request/4` returns `{:ok, %{status_code: _, body: _, headers: _}}` instead of an `HTTPoison.Response` struct. The module previously raised on every successful response, so no working caller depended on the old shape
- `RazorpayEx.Client` no longer forwards `:params` to the HTTP layer; the query string is encoded into the request URL
- List endpoints return a plain list of entities: `Payment.all/1` and friends now return `{:ok, [%Payment{}]}`, which matches their documented typespecs (previously they returned a `RazorpayEx.Entity` with no items)

### Fixed
- List endpoints (`Payment.all/1`, `Order.all/1`, `Refund.all/1`, `Customer.all/1`, `Order.payments/2`, `Refund.for_payment/2`) discarded the response: `{"entity": "collection", "count": N, "items": [...]}` was cast into an empty `RazorpayEx.Entity`. Collections now return the list of entities
- Entity casting silently dropped every field the target struct did not declare. Unmapped fields are now preserved in an `:extra` map on `RazorpayEx.Entity`, `RazorpayEx.Payment`, `RazorpayEx.Order`, `RazorpayEx.Refund` and `RazorpayEx.Customer`, and entity types without a module keep all of their fields
- `RazorpayEx.Error.from_map/2` looked up error modules under `Razorpay.Errors` (missing `Ex`), so specific error structs were never built. API errors are now always `%RazorpayEx.Error{}`
- `RazorpayEx.Errors.GatewayError` was an empty file; the module now exists
- `RazorpayEx.headers/1` stored headers under the wrong application key, so custom headers were never sent
- Request, configured and default headers now resolve in that order; the request header wins (previously the first value won)
- `RazorpayEx.Client` ignored the configured `:timeout` application setting
- Query parameters can now express repeated keys: `expand: ["card"]` and `expand: "card"` are sent as `expand[]=card`, and list values are sent as repeated `key[]` parameters (`URI.encode_query` raised on lists)
- `RazorpayEx.Request` raised `UndefinedFunctionError` on every success (`Entity.build/1` did not exist); it now delegates to `RazorpayEx.Client`
- `RazorpayEx.Constants.endpoint_path/1` raised because `Inflex` was never a dependency; endpoint names now come from a static map
- `RazorpayEx.Config` now also honours the `:api_url` / `:auth_url` keys, and the test suite configures `:api_base_url` correctly
- `RazorpayEx.Constants.user_agent/0` was interpolated at compile time and lost the version
- `Entity.build/2` dropped string keys, and `Entity.to_map/1` now drops an empty `:extra`

### Added
- `RazorpayEx.Query` for encoding query parameters, including `expand[]` and repeated keys
- Payload-mapping tests covering collections, lossless entity casting, error mapping, header precedence, query encoding and configuration

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
- Fix undefined function calls in the legacy `Request` module (`Config.get_headers`, `Config.get_auth`, `Config.api_url`)

## [0.1.2] - 2026-02-09

### Fixed
- Bug fix for OAuth function
- Cleaning redundant code

## [0.1.1] - 2026-01-30

### Added
- First release 