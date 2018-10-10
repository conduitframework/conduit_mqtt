defmodule ConduitMQTT.Plug.ParseExtendedPayload do
  use Conduit.Plug.Builder

  alias Conduit.ContentType

  @doc """
  Puts headers and attributes into the body of an MQTT message
  """
  @default_content_type "application/json"
  def call(message, next, opts) do
    %{"attributes" => attributes, "headers" => headers, "body" => body} =
      ContentType.parse(
        message,
        @default_content_type,
        opts
      ).body

    %{
      "content_encoding" => content_encoding,
      "content_type" => content_type,
      "correlation_id" => correlation_id,
      "created_at" => created_at,
      "created_by" => created_by,
      "destination" => destination,
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
    |> next.()
  end
end
