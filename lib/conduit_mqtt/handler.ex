defmodule ConduitMQTT.Handler do
  use Tortoise.Handler
  alias Conduit.Message
  import Conduit.Message
  require Logger

  def init(args) do
    {:ok, args}
  end

  def connection(status, [client_id: client_id, broker: broker, name: _name, opts: _opts] = state) do
    # `status` will be either `:up` or `:down`; you can use this to
    # inform the rest of your system if the connection is currently
    # open or closed; tortoise should be busy reconnecting if you get
    # a `:down`
    Logger.debug("Connection #{client_id} on broker #{inspect(broker)} is #{status}")
    ConduitMQTT.Meta.put_client_id_status(broker, client_id, status)
    {:ok, state}
  end

  def handle_message(topic, payload, [client_id: client_id, broker: broker, name: name, opts: opts] = state) do
    :ok = reply(broker, name, topic, payload, opts)
    {:ok, state}
  end

  def subscription(status, topic_filter, [client_id: client_id, broker: broker, name: name, opts: _opts] = state) do
    Logger.debug(
      "Subscription #{name} on broker #{inspect(broker)} client_id #{client_id} topic filter #{topic_filter} is #{
        status
      }"
    )

    ConduitMQTT.Meta.put_subscription_status(broker, name, status)
    {:ok, state}
  end

  def terminate(_reason, _state) do
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

  defp build_message(topic, payload, _props) do
    %Message{}
    |> put_source(topic)
    |> put_body(payload)
    |> put_header("routing_key", Enum.join(topic, "/"))

    # |> Props.put(props)
  end
end
