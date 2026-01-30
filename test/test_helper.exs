# test/test_helper.exs
ExUnit.start()

# Configure test credentials
Application.put_env(:razorpay_ex, :key_id, "test_key_id")
Application.put_env(:razorpay_ex, :key_secret, "test_key_secret")
Application.put_env(:razorpay_ex, :enable_logging, false)
