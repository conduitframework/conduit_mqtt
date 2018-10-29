defmodule ConduitMQTT.ConnPool do
  @moduledoc """
  Supervises the pool of connections to message queue
  """
  @pool_size 5

  def child_spec([broker, opts]) do
    pool_name = name(broker)

    conn_pool_opts = [
      name: {:local, pool_name},
      worker_module: ConduitMQTT.Conn,
      size: opts[:conn_pool_size] || @pool_size,
      strategy: :fifo,
      max_overflow: 0
    ]

    %{
      id: name(broker),
      start: {:poolboy, :start_link, [conn_pool_opts, [broker, "pub_pool_member", :pub, opts]]},
      type: :worker
    }
  end

  def name(broker) do
    Module.concat(broker, Adapter.ConnPool)
  end
end
