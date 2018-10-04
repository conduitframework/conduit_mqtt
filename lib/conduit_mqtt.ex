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
  alias Conduit.Message

  @type broker :: module
  @type client_id :: String.t()

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
    Meta.put_setup_status(broker, :complete) #TODO; put this here for now
    Supervisor.start_link(__MODULE__, [broker, topology, subscribers, opts], name: name(broker))
  end

  def init([broker, topology, subscribers, opts]) do
    Logger.info("MQTT Adapter started!")

    children = [
      {ConduitMQTT.ConnPool, [broker, opts]}, #TODO rename to PubPool
      {ConduitMQTT.SubPool, [broker, subscribers, opts]},
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
    #props = ConduitMQTT.Props.get(message) #TODO MQTT opts
    with_client_id(broker, fn client_id ->
      qos = Message.get_header(message, "qos")
      Logger.info("Publishing from client_id #{client_id} to #{message.destination} with qos #{qos}")
      Tortoise.publish_sync(client_id, message.destination, message.body, [qos: qos]) #TODO: how to do qos
    end)
  end

  @spec with_client_id(broker, (client_id -> term)) :: {:error, term} | {:ok, term} | term
  def with_client_id(broker, fun) when is_function(fun, 1) do
    with {:ok, client_id} <- get_client_id(broker, @pool_size) do
      fun.(client_id)
    end
  end


  @doc false
  defp get_client_id(broker, retries) do
    pool = ConduitMQTT.ConnPool.name(broker)

    Util.retry([attempts: retries], fn ->
        :poolboy.transaction(pool, &ConduitMQTT.Conn.get_client_id(&1))
      end
    )
  end
end
