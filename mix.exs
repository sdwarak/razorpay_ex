defmodule RazorpayEx.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/sdwarak/razorpay_ex"
  @description "Elixir client for RazorpayEx API - Unofficial library for RazorpayEx payment gateway"

  def project do
    [
      app: :razorpay_ex,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: @description,
      package: package(),
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :ssl]
    ]
  end

  defp deps do
    [
      {:httpoison, "~> 1.8 or ~> 2.0"},
      {:jason, "~> 1.2"},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.15", only: :test, runtime: false},
      {:bypass, "~> 2.1", only: :test},
      {:mox, "~> 1.0", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["Dwarakanath Soundararajan"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "RazorpayEx API Docs" => "https://razorpay.com/docs/api/"
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      name: "RazorpayEx",
      source_ref: "v#{@version}",
      canonical: "https://hexdocs.pm/razorpay_ex",
      source_url: @source_url,
      extras: [
        "README.md",
        "CHANGELOG.md",
        "LICENSE"
      ],
      groups_for_modules: [
        "Core": [
          RazorpayEx,
          RazorpayEx.Client,
          RazorpayEx.Config,
          RazorpayEx.Constants,
          RazorpayEx.Entity,
          RazorpayEx.Error,
          RazorpayEx.Request,
          RazorpayEx.Webhook
        ],
        "Resources": [
          RazorpayEx.Payment,
          RazorpayEx.Order,
          RazorpayEx.Refund,
          RazorpayEx.Customer,
          RazorpayEx.Card,
          RazorpayEx.Invoice,
          RazorpayEx.PaymentLink,
          RazorpayEx.Settlement
        ],
        "Errors": [
          RazorpayEx.Errors.BadRequestError,
          RazorpayEx.Errors.GatewayError,
          RazorpayEx.Errors.ServerError
        ]
      ]
    ]
  end
end
