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
  @type client_id :: String.t()

  @pool_size 5

  defmodule NeedsWrappingError do
    @moduledoc """
    Exception raised when a message is published with attributes or headers that need wrapping.
    """
    defexception [:message]
  end

  def child_spec([broker, _, _, _] = args) do
    %{
      id: name(broker),
      start: {__MODULE__, :start_link, args},
      type: :supervisor
    }
  end

  def start_link(broker, topology, subscribers, opts) do
    Meta.create(broker, @pool_size, Enum.count(Map.keys(subscribers)))
    Supervisor.start_link(__MODULE__, [broker, topology, subscribers, opts], name: name(broker))
  end

  def init([broker, topology, subscribers, opts]) do
    if !Enum.empty?(topology) do
      Logger.warn("Topology should be empty list for MQTT Adapter")
    end

    Logger.info("MQTT Adapter started!")

    children = [
      {ConduitMQTT.SubPool, [broker, subscribers, opts]},
      # TODO rename to PubPool
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
    # props = ConduitMQTT.Props.get(message) #TODO MQTT opts

    error_if_needs_wrap(message)

    with_client_id(broker, fn client_id ->
      Tortoise.publish_sync(client_id, message.destination, message.body, opts)
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
    end)
  end

  defp error_if_needs_wrap(message) do
    if !Conduit.Message.get_private(message, :wrapped) && (has_attributes(message) || has_headers(message)) do
      raise NeedsWrappingError,
            "Message headers and attributes are not supported in Conduit MQTT adapter without wrapping/unwrapping using ConduitMQTT.Plug.Wrap and ConduitMQTT.Plug.Unwrap"
    end
  end

  @attributes ~w(content_encoding content_type correlation_id created_at created_by message_id user_id)a
  defp has_attributes(message) do
    Enum.any?(
      @attributes,
      fn attribute ->
        Map.get(message, attribute) != nil
      end
    )
  end

  defp has_headers(message) do
    message.headers != %{}
  end
end
