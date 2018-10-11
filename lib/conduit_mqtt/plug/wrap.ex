defmodule ConduitMQTT.Plug.Wrap do
  use Conduit.Plug.Builder

  @doc """
  Puts headers and attributes into the body of an MQTT message
  """

  def call(message, next, opts) do
    wrap_fn = Keyword.get(opts, :wrap_fn, &default_wrap/1)

    message
    |> wrap_fn.()
    |> Conduit.Message.put_private(:wrapped, true)
    |> next.()
  end

  defp default_wrap(
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
         } = message
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
    |> put_body(%{"attributes" => attributes, "headers" => headers, "body" => body})
  end
end
