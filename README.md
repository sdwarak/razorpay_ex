# RazorpayEx

[![Hex.pm](https://img.shields.io/hexpm/v/razorpay.svg)](https://hex.pm/packages/razorpay)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/razorpay/)
[![License](https://img.shields.io/hexpm/l/razorpay.svg)](https://github.com/sdwarak/razorpay_elixir/blob/master/LICENSE)
[![Coverage Status](https://coveralls.io/repos/github/sdwarak/razorpay_elixir/badge.svg?branch=master)](https://coveralls.io/github/sdwarak/razorpay_elixir)

An Elixir client for the Razorpay API, providing a clean and intuitive interface for integrating Razorpay payments into your Elixir applications.

## Features

- Still in experimental phase, use with caution
- API coverage for basic uses cases
- Support for both Basic Auth and OAuth authentication
- Webhook signature verification
- Comprehensive error handling with specific error types
- Well-documented with detailed examples
- Built-in testing utilities
- Follows Elixir best practices

## Installation

The package can be installed
by adding `razorpay_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:razorpay_ex, "~> 0.4.0"}
  ]
end
```

### Requirements

- Elixir 1.17 or later
- Erlang/OTP 27 or later

These are the minimum versions supported by `httpoison` 3.x and its `hackney`
4.x HTTP backend.

## Verifying a payment

Checkout callbacks are signed with your **key secret**. Verify the signature
before fulfilling an order:

```elixir
if RazorpayEx.Utility.verify_payment_signature(params) do
  fulfil_order(params["razorpay_order_id"])
else
  # tampered or replayed callback
  :invalid_signature
end
```

Webhooks are signed with your **webhook secret** over the raw request body:

```elixir
RazorpayEx.Webhook.verify(raw_body, signature, webhook_secret)
```

## Production notes

- Treat webhooks (`payment.captured`, `order.paid`) as the source of truth and
  verify them over the raw body, before JSON parsing.
- Pass `idempotency_key:` to `RazorpayEx.Refund.create/3` and reuse it when
  retrying, so a refund can never be created twice.
- Pass `retry: n` only for requests you can safely repeat.
- Use `RazorpayEx.Paginator.all/3` to reconcile every record in a date range.
- Requires Elixir 1.17+ and Erlang/OTP 27+.

License
MIT License - see LICENSE file for details.

Disclaimer
This library is not officially supported by Razorpay. It's a community-maintained project modeled after the official Ruby SDK.