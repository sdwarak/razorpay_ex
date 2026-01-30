# config/config.exs
import Config

config :razorpay_ex,
  http_client: RazorpayEx.HttpAdapter,
  api_url: "https://api.razorpay.com/v1",
  auth_base_url: "https://auth.razorpay.com/v2",
  timeout: 30_000
