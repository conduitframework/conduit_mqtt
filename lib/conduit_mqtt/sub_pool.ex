defmodule ConduitMQTT.SubPool do
  @moduledoc """
  Supervises all the subscriptions to queues
  """
  use Supervisor

  def child_spec([broker, _, _] = args) do
    %{
      id: name(broker),
      start: {__MODULE__, :start_link, args},
      type: :supervisor
    }
  end

  def start_link(broker, subscribers, opts) do
    Supervisor.start_link(__MODULE__, [broker, subscribers, opts], name: name(broker))
  end

  def init([broker, subscribers, adapter_opts]) do
    children =
      Enum.map(subscribers, fn {name, opts} ->
        client_id = opts[:client_id] || ConduitMQTT.Conn.generate_client_id() #allow passing in for testing or single static subscriber

        adapter_opts = put_in(adapter_opts[:connection_opts][:subscriptions], [{opts[:from], opts[:qos]}])
        adapter_opts = put_in(adapter_opts[:connection_opts][:client_id], client_id)
        adapter_opts = put_in(adapter_opts[:connection_opts][:clean_session], false)
        {ConduitMQTT.Conn, [broker: broker, name: name, opts: opts ++ adapter_opts]}
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end

  def name(broker) do
    Module.concat(broker, Adapter.SubPool)
  end
end
