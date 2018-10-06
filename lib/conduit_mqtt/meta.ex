defmodule ConduitMQTT.Meta do
  @moduledoc false
  require Logger

  @type broker :: atom
  @type status :: :incomplete | :complete
  @type client_id :: String.t()
  @type pool_size :: Integer.t()
  @type sub_count :: Integer.t()
  @type subscription :: String.t()

  @spec create(broker, pool_size, sub_count) :: atom
  def create(broker, pool_size, sub_count) do
    table =
      broker
      |> meta_name()

    table
    |> :ets.new([:set, :public, :named_table])

    table
    |> :ets.insert({:client_count, pool_size + sub_count})

    table
    |> :ets.insert({:subscriber_count, sub_count})
  end

  @spec delete(broker) :: true
  def delete(broker) do
    broker
    |> meta_name()
    |> :ets.delete()
  end

  @spec put_setup_status(broker, status) :: boolean
  def put_setup_status(broker, status) do
    insert_status(broker, :setup, status)
  end

  @spec get_setup_status(broker) :: status
  def get_setup_status(broker) do
    lookup_status(broker, :setup)
  end

  @spec put_client_id_status(broker, client_id, status) :: boolean
  def put_client_id_status(broker, client_id, status) do
    insert_client_id_status(broker, client_id, status)
  end

  @spec put_subscription_status(broker, subscription, status) :: boolean
  def put_subscription_status(broker, subscription, status) do
    insert_subscription_status(broker, subscription, status)
  end

  @spec get_client_id_status(broker, client_id) :: status
  def get_client_id_status(broker, client_id) do
    lookup_client_id_status(broker, client_id)
  end

  def get_all(broker) do
    table = meta_name(broker)
    :ets.match(table, {:"$1", :"$2"})
  end

  defp meta_name(broker) do
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

  defp lookup_client_id_status(broker, client_id, fallback \\ fn -> :incomplete end) do
    broker
    |> meta_name()
    |> :ets.lookup(client_id)
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
