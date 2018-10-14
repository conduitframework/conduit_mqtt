defmodule ConduitMQTT.Plug.Unwrap do
  @moduledoc """
  Plug to help unwrap headers and attributes from the MQTT body payload
  """
  use Conduit.Plug.Builder

  require Logger

  @doc """
  Gets headers and attributes from the wrapped body of an MQTT message
  """

  def call(message, next, opts) do
    unwrap_fn = Keyword.get(opts, :unwrap_fn, &default_unwrap/1)

    message
    |> unwrap_fn.()
    |> next.()
  end

  defp default_unwrap(message) do
    %{"attributes" => attributes, "headers" => headers, "body" => body} = message.body

    %{
      "content_encoding" => content_encoding,
      "content_type" => content_type,
      "correlation_id" => correlation_id,
      "created_at" => created_at,
      "created_by" => created_by,
      "message_id" => message_id,
      "user_id" => user_id
    } = attributes

    message
    # Merge here because lower down code is putting in a routing key, and source
    |> put_headers(Map.merge(message.headers, headers))
    |> put_body(body)
    |> put_content_encoding(content_encoding)
    |> put_content_type(content_type)
    |> put_correlation_id(correlation_id)
    |> put_created_at(created_at)
    |> put_created_by(created_by)
    |> put_message_id(message_id)
    |> put_user_id(user_id)
  end
end
