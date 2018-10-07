defmodule ConduitMQTT.Meta do
  @moduledoc false
  use GenServer
  require Logger
  alias ConduitMQTT.Meta


  @type broker :: atom
  @type status :: :incomplete | :complete
  @type client_id :: String.t()
  @type pool_size :: Integer.t()
  @type sub_count :: Integer.t()
  @type subscription :: String.t()

  ## Client API
  def child_spec([broker, _, _] = args) do
    %{
      id: meta_name(broker),
      start: {__MODULE__, :start_link, [args]},
      type: :worker
    }
  end

  def start_link([broker, _, _] = opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: meta_name(broker))
  end

  @spec get_setup_status(broker) :: status
  def get_setup_status(broker) do
    GenServer.call(meta_name(broker), {:get_setup_status, broker})
  end

  @spec put_client_id_status(broker, client_id, status) :: boolean
  def put_client_id_status(broker, client_id, status) do
    GenServer.cast(meta_name(broker), {:put_client_id_status, broker, client_id, status})
  end

  @spec put_subscription_status(broker, subscription, status) :: boolean
  def put_subscription_status(broker, subscription, status) do
    GenServer.cast(meta_name(broker), {:put_subscription_status, broker, subscription, status})
  end

  ## Server Callbacks
  def init(opts) do
    # Process.flag(:trap_exit, true) #TODO what does this do?
    send(self(), :setup_table)
    {:ok, opts}
  end

  def handle_info(:setup_table,  [broker, pool_size, sub_count] = state) do
    create(broker, pool_size, sub_count)
    {:noreply, state}
  end

  def handle_cast({:put_client_id_status, broker, client_id, status}, state) do
    insert_client_id_status(broker, client_id, status)
    {:noreply, state}
  end

  def handle_cast({:put_subscription_status, broker, subscriber_name, status}, state) do
    insert_subscription_status(broker, subscriber_name, status)
    {:noreply, state}
  end

  def handle_call({:get_setup_status, broker}, _from, state) do
    {:reply, lookup_status(broker, :setup), state}
  end

  @spec create(broker, pool_size, sub_count) :: atom
  defp create(broker, pool_size, sub_count) do
    table =
      broker
      |> meta_name()

    table
    |> :ets.new([:set, :private, :named_table])

    table
    |> :ets.insert({:client_count, pool_size + sub_count})

    table
    |> :ets.insert({:subscriber_count, sub_count})
  end

  @spec delete(broker) :: true
  defp delete(broker) do
    broker
    |> meta_name()
    |> :ets.delete()
  end

  @spec put_setup_status(broker, status) :: boolean
  defp put_setup_status(broker, status) do
    insert_status(broker, :setup, status)
  end

  def get_all(broker) do
    table = meta_name(broker)
    :ets.match(table, {:"$1", :"$2"})
  end

  def meta_name(broker) do
    Module.concat([broker, Meta])
  end

  defp insert_status(broker, key, status) do
    broker
    |> meta_name()
    |> :ets.insert({key, status})
  end

  defp insert_client_id_status(broker, client_id, status) do
    broker
    |> meta_name()
    |> :ets.insert({client_id, status})

    update_broker_status(broker)
  end

  defp insert_subscription_status(broker, subscription, status) do
    broker
    |> meta_name()
    |> :ets.insert({subscription, status})

    update_broker_status(broker)
  end

  defp lookup_status(broker, key, fallback \\ fn -> :incomplete end) do
    broker
    |> meta_name()
    |> :ets.lookup(key)
    |> case do
      [] ->
        fallback.()

      [{_, status} | _] ->
        status
    end
  end

  defp update_broker_status(broker) do
    table = meta_name(broker)
    [{_, client_count}] = :ets.lookup(meta_name(broker), :client_count)
    [{_, subscriber_count}] = :ets.lookup(meta_name(broker), :subscriber_count)

    count_of_things_up = :ets.select_count(table, [{{:"$1", :up}, [], [true]}])

    Logger.debug(
      "Broker #{broker} has #{count_of_things_up} of #{client_count + subscriber_count} clients and subscriptions up"
    )

    if count_of_things_up == client_count + subscriber_count do
      Logger.info("Marking broker #{broker} up")
      put_setup_status(broker, :complete)
    end
  end

  def key_stream(table_name) do
    Stream.resource(
      fn -> :ets.first(table_name) end,
      fn
        :"$end_of_table" -> {:halt, nil}
        previous_key -> {[previous_key], :ets.next(table_name, previous_key)}
      end,
      fn _ -> :ok end
    )
  end
end
