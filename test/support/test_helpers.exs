# test/support/test_helpers.exs
defmodule RazorpayEx.TestHelpers do
  @moduledoc """
  Test helpers for RazorpayEx.
  """

  def setup_basic_auth do
    Application.put_env(:razorpay_ex, :auth_type, :basic)
    Application.put_env(:razorpay_ex, :key_id, "test_key_id")
    Application.put_env(:razorpay_ex, :key_secret, "test_key_secret")
  end

  def setup_oauth_auth do
    Application.put_env(:razorpay_ex, :auth_type, :oauth)
    Application.put_env(:razorpay_ex, :access_token, "test_oauth_token")
  end

  def clear_auth do
    Application.delete_env(:razorpay_ex, :auth_type)
    Application.delete_env(:razorpay_ex, :key_id)
    Application.delete_env(:razorpay_ex, :key_secret)
    Application.delete_env(:razorpay_ex, :access_token)
  end

  def mock_successful_response(entity_type, id, attributes) do
    body =
      Map.merge(%{
        "id" => id,
        "entity" => Atom.to_string(entity_type),
        "created_at" => :os.system_time(:seconds)
      }, attributes)
      |> Jason.encode!()

    %HTTPoison.Response{
      status_code: 200,
      body: body
    }
  end

  def mock_error_response(code, description, status_code \\ 400) do
    body = Jason.encode!(%{
      "error" => %{
        "code" => code,
        "description" => description
      }
    })

    %HTTPoison.Response{
      status_code: status_code,
      body: body
    }
  end
end
