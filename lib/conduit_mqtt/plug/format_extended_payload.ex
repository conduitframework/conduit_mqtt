defmodule ConduitMQTT.Plug.FormatExtendedPayload do
  use Conduit.Plug.Builder

  alias Conduit.ContentType

  @doc """
  Puts headers and attributes into the body of an MQTT message
  """
  @default_content_type "application/json"
  def call(
        %Conduit.Message{
          headers: headers,
          body: body,
          content_encoding: content_encoding,
          content_type: content_type,
          correlation_id: correlation_id,
          created_at: created_at,
          created_by: created_by,
          destination: destination,
          message_id: message_id,
          user_id: user_id
        } = message,
        next,
        opts
      ) do
    attributes = %{
      "content_encoding" => content_encoding,
      "content_type" => content_type,
      "correlation_id" => correlation_id,
      "created_at" => created_at,
      "created_by" => created_by,
      "destination" => destination,
      "message_id" => message_id,
      "user_id" => user_id
    }

    message
    |> put_body(%{attributes: attributes, headers: headers, body: body})
    |> ContentType.format(@default_content_type, opts)
    |> next.()
  end
end
