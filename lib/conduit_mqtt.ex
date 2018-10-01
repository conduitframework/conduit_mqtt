defmodule ConduitMQTT do
  @moduledoc """
  MQTT adapter for Conduit.
  #TODO: put docs for connection_opts
  """
  use Conduit.Adapter
  use Supervisor
  require Logger
  alias ConduitMQTT.Util
  alias ConduitMQTT.Meta

  @type broker :: module

  @pool_size 5

  def child_spec([broker, _, _, _] = args) do
    %{
      id: name(broker),
      start: {__MODULE__, :start_link, args},
      type: :supervisor
    }
  end

  def start_link(broker, topology, subscribers, opts) do
    Meta.create(broker)
    #Meta.put_setup_status(broker, :complete) #TODO; put this here for now
    Supervisor.start_link(__MODULE__, [broker, topology, subscribers, opts], name: name(broker))
  end

  def init([broker, topology, subscribers, opts]) do
    Logger.info("MQTT Adapter started!")

    children = [
      {ConduitMQTT.ConnPool, [broker, opts]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def name(broker) do
    Module.concat(broker, Adapter)
  end

  # TODO: Remove when conduit goes to 1.0
  # Conduit will never call this if publish/4 is defined
  def publish(message, _config, _opts) do
    {:ok, message}
  end

  def publish(broker, message, _config, opts) do
    #exchange = Keyword.get(opts, :exchange)
    #props = ConduitMQTT.Props.get(message) #TODO MQTT opts

    Tortoise.publish("1", message.destination, message.body,  qos: 0)
  end

  @doc false
  defp get_conn(broker, retries) do
    pool = ConduitMQTT.ConnPool.name(broker)

    Util.retry([attempts: retries], fn ->
      :poolboy.transaction(pool, &GenServer.call(&1, :conn))
    end)
  end
end
