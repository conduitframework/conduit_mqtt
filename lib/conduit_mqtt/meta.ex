defmodule ConduitMQTT.Meta do
  @moduledoc false

  @type broker :: atom
  @type status :: :incomplete | :complete

  @spec create(broker) :: atom
  def create(broker) do
    broker
    |> meta_name()
    |> :ets.new([:set, :public, :named_table])
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

  defp meta_name(broker) do
    Module.concat([broker, Meta])
  end

  defp insert_status(broker, key, status) do
    broker
    |> meta_name()
    |> :ets.insert({key, status})
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
end
