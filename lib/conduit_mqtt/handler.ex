defmodule ConduitMQTT.Handler do
  use Tortoise.Handler
  alias Conduit.Message
  import Conduit.Message
  require Logger


  def init(args) do
    Logger.info("init handler %%%%%%")
    {:ok, args}
  end

  def connection(status, state) do
    # `status` will be either `:up` or `:down`; you can use this to
    # inform the rest of your system if the connection is currently
    # open or closed; tortoise should be busy reconnecting if you get
    # a `:down`
    {:ok, state}
  end

  def handle_message(topic, payload, [broker: broker, name: name, opts: opts] = state) do
    Logger.info("got message: #{inspect(topic)} #{inspect(payload)} #{inspect(state)}")
    :ok = reply(broker, name, topic, payload, opts)
    {:ok, state}
  end

  def subscription(status, topic_filter, state) do
    {:ok, state}
  end

  def terminate(reason, state) do
    # tortoise doesn't care about what you return from terminate/2,
    # that is in alignment with other behaviours that implement a
    # terminate-callback
    :ok
  end

  defp reply(broker, name, topic, payload, props) do
    message = build_message(topic, payload, props)

    case broker.receives(name, message) do
      %Message{status: :ack} ->
        :ok

      %Message{status: :nack} ->
        :error
    end
  catch
    _error ->
      :error
  end

  defp build_message(topic, payload, props) do
    %Message{}
    |> put_source(topic)
    |> put_body(payload)
    |> put_header("routing_key", Enum.join(topic,"/"))
    #|> Props.put(props)
  end
end