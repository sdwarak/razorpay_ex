defmodule RazorpayEx.ClientTest do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  describe "request/4" do
    test "handles successful response" do
      # Mock HTTPoison
      expect(HTTPoison.Mock, :request, fn :get, _url, _body, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"id" => "pay_test_123", "amount" => 50000})
         }}
      end)

      assert {:ok, %{"id" => "pay_test_123", "amount" => 50000}} =
               RazorpayEx.Client.request(:get, "/payments/pay_test_123")
    end

    test "handles error response" do
      expect(HTTPoison.Mock, :request, fn :get, _url, _body, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 400,
           body: Jason.encode!(%{"error" => %{"code" => "BAD_REQUEST_ERROR"}})
         }}
      end)

      assert {:error, %RazorpayEx.Error{code: "BAD_REQUEST_ERROR"}} =
               RazorpayEx.Client.request(:get, "/payments/invalid_id")
    end
  end
end
