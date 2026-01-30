# test/test_helper.exs


# Configure Mox for mocking
Mox.defmock(RazorpayEx.HttpClientMock, for: RazorpayEx.HttpClient)

# Set HTTP client to use mock in test environment
Application.put_env(:razorpay_ex, :http_client, RazorpayEx.HttpClientMock)

# Set test configuration
Application.put_env(:razorpay_ex, :api_url, "https://api.razorpay.com/v1")
Application.put_env(:razorpay_ex, :auth_base_url, "https://auth.razorpay.com/v2")
Application.put_env(:razorpay_ex, :timeout, 5000)

# Load support files
# Code.require_file("support/http_client_stub.exs", __DIR__)  # REMOVE THIS LINE
ExUnit.start()
