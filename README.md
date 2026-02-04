# RazorpayEx

[![Hex.pm](https://img.shields.io/hexpm/v/razorpay.svg)](https://hex.pm/packages/razorpay)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/razorpay/)
[![License](https://img.shields.io/hexpm/l/razorpay.svg)](https://github.com/sdwarak/razorpay_elixir/blob/master/LICENSE)
[![Coverage Status](https://coveralls.io/repos/github/sdwarak/razorpay_elixir/badge.svg?branch=master)](https://coveralls.io/github/sdwarak/razorpay_elixir)

An Elixir client for the Razorpay API, providing a clean and intuitive interface for integrating Razorpay payments into your Elixir applications.

## Features

- API coverage for basic uses cases
- Support for both Basic Auth and OAuth authentication
- Webhook signature verification
- Comprehensive error handling with specific error types
- Well-documented with detailed examples
- Built-in testing utilities
- Follows Elixir best practices

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `razorpay_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:razorpay_ex, "~> 0.1.0"}
  ]
end
```

License
MIT License - see LICENSE file for details.

Disclaimer
This library is not officially supported by Razorpay. It's a community-maintained project modeled after the official Ruby SDK.