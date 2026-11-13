defmodule RazorpayEx.Paginator do
  @moduledoc """
  Fetches every page of a Razorpay list endpoint.

  Razorpay list endpoints are page based: `count` sets the page size (maximum
  100) and `skip` the offset. `Payment.all/1` and friends return a single page;
  this module walks the pages for you and returns everything in one list.

  ## Examples

      # Every payment captured in a date range
      {:ok, payments} =
        RazorpayEx.Paginator.all(:payment, %{"from" => 1_700_000_000, "to" => 1_700_086_400},
          page_size: 100
        )

      # Explicit path, a couple of pages at most
      {:ok, refunds} = RazorpayEx.Paginator.all("/refunds", %{}, page_size: 50, max_pages: 2)

  Pagination stops as soon as a page is shorter than `:page_size`, which is how
  Razorpay signals the last page. `:max_pages` (default #{100}) bounds a runaway
  loop; hitting the limit returns an error rather than a silently truncated
  list.
  """

  alias RazorpayEx.{Client, Constants, Error}

  @default_page_size 100
  @default_max_pages 100

  @type params :: map() | keyword()

  @doc """
  Fetches all pages and returns the combined list.

  `resource_or_path` is either a resource atom (`:payment`, `:order`, `:refund`,
  `:customer`) or an explicit path such as `"/payments"`.

  ## Options

    * `:page_size` - items requested per page, 1 to 100 (default #{@default_page_size})
    * `:max_pages` - safety limit on the number of pages (default #{@default_max_pages})
    * any other option (`:timeout`, `:headers`, `:retry`, `:host`) is passed to
      `RazorpayEx.Client.request/4`
  """
  @spec all(atom() | String.t(), params(), keyword()) ::
          {:ok, list(struct())} | {:error, Error.t()}
  def all(resource_or_path, params \\ %{}, opts \\ []) do
    path = path_for(resource_or_path)
    page_size = Keyword.get(opts, :page_size, @default_page_size)
    max_pages = Keyword.get(opts, :max_pages, @default_max_pages)

    cond do
      not is_integer(page_size) or page_size < 1 or page_size > 100 ->
        {:error, Error.new(:invalid_page_size, "page_size must be between 1 and 100")}

      not is_integer(max_pages) or max_pages < 1 ->
        {:error, Error.new(:invalid_max_pages, "max_pages must be a positive integer")}

      true ->
        request_opts = Keyword.drop(opts, [:page_size, :max_pages])
        fetch_pages(path, Map.new(params), request_opts, page_size, max_pages, 0, [])
    end
  end

  defp fetch_pages(path, params, opts, page_size, max_pages, page, pages) do
    skip = page * page_size

    params =
      params
      |> Map.drop([:count, :skip, "count", "skip"])
      |> Map.merge(%{count: page_size, skip: skip})

    case Client.request(:get, path, %{}, Keyword.put(opts, :params, params)) do
      {:ok, items} when is_list(items) ->
        pages = [items | pages]

        cond do
          length(items) < page_size -> {:ok, pages |> Enum.reverse() |> List.flatten()}
          page + 1 >= max_pages -> {:error, limit_error(max_pages)}
          true -> fetch_pages(path, params, opts, page_size, max_pages, page + 1, pages)
        end

      {:ok, _other} ->
        {:error, Error.new(:invalid_response, "expected a list page from the API")}

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp limit_error(max_pages) do
    Error.new(
      "PAGINATION_LIMIT",
      "Reached max_pages (#{max_pages}) before the last page; raise :max_pages or narrow the filters"
    )
  end

  defp path_for(path) when is_binary(path), do: path
  defp path_for(resource) when is_atom(resource), do: "/" <> Constants.endpoint_path(resource)
end
