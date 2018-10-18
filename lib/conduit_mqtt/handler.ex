defmodule ConduitMQTT.Handler do
  @moduledoc """
  Tortoise.Handler implementation
  """

  use Tortoise.Handler
  alias Conduit.Message
  import Conduit.Message
  require Logger

  defmodule State do
    @moduledoc """
    State struct for handler
    """
    defstruct [:client_id, :broker, :name, :conn_type, :opts]
  end

  def init(args) do
    {:ok, struct!(State, args)}
  end

  def connection(status, %State{client_id: client_id, broker: broker, name: name, conn_type: conn_type} = state) do
    # `status` will be either `:up` or `:down`; you can use this to
    # inform the rest of your system if the connection is currently
    # open or closed; tortoise should be busy reconnecting if you get
    # a `:down`
    Logger.debug(fn -> "Connection #{client_id} on broker #{inspect(broker)} is #{status}" end)
    ConduitMQTT.Meta.put_client_id_status(broker, client_id, status)

    if conn_type == :sub && status != :up do
      Logger.debug(fn -> "Marking subscription #{name} down" end)
      ConduitMQTT.Meta.put_subscription_status(broker, name, :down)
    end

    {:ok, state}
  end

  def handle_message(
        topic,
        payload,
        %State{client_id: client_id, broker: broker, name: name, opts: opts} = state
      ) do
    Logger.debug(fn ->
      "Subscriber #{name} on broker #{inspect(broker)} client_id #{client_id} got message: #{inspect(payload)} on topic: #{
        inspect(topic)
      }"
    end)

    :ok = reply(broker, name, topic, payload, opts)
    {:ok, state}
  end

  def subscription(
        status,
        topic_filter,
        %State{client_id: client_id, broker: broker, name: name} = state
      ) do
    Logger.debug(fn ->
      "Subscription #{name} on broker #{inspect(broker)} client_id #{client_id} topic filter #{topic_filter} is #{
        status
      }"
    end)

    ConduitMQTT.Meta.put_subscription_status(broker, name, status)
    {:ok, state}
  end

  def terminate(
        _reason,
        %State{client_id: client_id, broker: broker, name: name} = _state
      ) do
    # tortoise doesn't care about what you return from terminate/2,
    # that is in alignment with other behaviours that implement a
    # terminate-callback
    ConduitMQTT.Meta.delete_client_id(broker, client_id)
    ConduitMQTT.Meta.delete_subscription(broker, name)
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
