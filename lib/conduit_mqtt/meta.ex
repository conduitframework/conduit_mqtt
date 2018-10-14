defmodule ConduitMQTT.Meta do
  @moduledoc false
  require Logger

  @type broker :: atom
  @type status :: :up | :down
  @type client_id :: String.t()
  @type pool_size :: integer()
  @type sub_count :: integer()
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

  @spec delete_client_id(broker, client_id) :: true
  def delete_client_id(broker, client_id) do
    broker
    |> meta_name()
    |> :ets.delete({:client, client_id})
  end

  @spec delete_subscription(broker, subscription) :: true
  def delete_subscription(broker, subscription) do
    broker
    |> meta_name()
    |> :ets.delete({:subscription, subscription})
  end

  @spec get_broker_status(broker) :: status
  def get_broker_status(broker) do
    calculate_broker_status(broker)
  end

  @spec get_client_id_status(broker, client_id) :: status
  def get_client_id_status(broker, client_id) do
    lookup_client_id_status(broker, client_id)
  end

  @spec get_subscription_status(broker, subscription) :: status
  def get_subscription_status(broker, subscription) do
    lookup_subscription_status(broker, subscription)
  end

  @spec put_client_id_status(broker, client_id, status) :: boolean
  def put_client_id_status(broker, client_id, status) do
    insert_client_id_status(broker, client_id, status)
  end

  @spec put_subscription_status(broker, subscription, status) :: boolean
  def put_subscription_status(broker, subscription, status) do
    insert_subscription_status(broker, subscription, status)
  end

  def get_clients(broker) do
    lookup_clients(broker)
  end

  def get_subscriptions(broker) do
    lookup_subscriptions(broker)
  end

  def get_all(broker) do
    table = meta_name(broker)
    :ets.match(table, {:"$1", :"$2"})
  end

  defp meta_name(broker) do
    Module.concat([broker, Meta])
  end

  defp insert_client_id_status(broker, client_id, status) do
    broker
    |> meta_name()
    |> :ets.insert({{:client, client_id}, status})
  end

  defp insert_subscription_status(broker, subscription, status) do
    broker
    |> meta_name()
    |> :ets.insert({{:subscription, subscription}, status})
  end

  defp lookup_client_id_status(broker, client_id, fallback \\ fn -> nil end) do
    broker
    |> meta_name()
    |> :ets.lookup({:client, client_id})
    |> case do
      [] ->
        fallback.()

      [{_, status} | _] ->
        status
    end
  end

  defp lookup_subscription_status(broker, subscription, fallback \\ fn -> nil end) do
    broker
    |> meta_name()
    |> :ets.lookup({:subscription, subscription})
    |> case do
      [] ->
        fallback.()

      [{_, status} | _] ->
        status
    end
  end

  defp lookup_clients(broker) do
    broker
    |> meta_name()
    |> :ets.match({{:client, :"$1"}, :"$2"})
  end

  defp lookup_subscriptions(broker) do
    broker
    |> meta_name()
    |> :ets.match({{:subscription, :"$1"}, :"$2"})
  end

  defp calculate_broker_status(broker) do
    table = meta_name(broker)
    [{_, client_count}] = :ets.lookup(meta_name(broker), :client_count)
    [{_, subscriber_count}] = :ets.lookup(meta_name(broker), :subscriber_count)

    count_of_clients_up = :ets.select_count(table, [{{{:client, :"$1"}, :up}, [], [true]}])
    count_of_subscribers_up = :ets.select_count(table, [{{{:subscription, :"$1"}, :up}, [], [true]}])

    Logger.debug(fn ->
      "Broker #{broker} has #{count_of_clients_up} of #{client_count} clients and #{count_of_subscribers_up} of #{
        subscriber_count
      } subscriptions up"
    end)

    status = if count_of_clients_up + count_of_subscribers_up == client_count + subscriber_count, do: :up, else: :down
    Logger.debug(fn -> "Broker #{broker} is #{status}" end)
    status
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
