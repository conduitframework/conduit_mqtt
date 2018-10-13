defmodule ConduitMQTT.EventLogger do
  @moduledoc """
  Can be used to log Tortoise Events (NOT USED RIGHT NOW)
  """
  use GenServer
  require Logger

  ## Client API
  def child_spec(args) do
    %{
      id: ConduitMQTT.EventLogger,
      start: {__MODULE__, :start_link, [args]},
      type: :worker
    }
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  ## Server Callbacks
  def init(opts) do
    Tortoise.Events.register(:_, :status)
    {:ok, opts}
  end

  def handle_info({{Tortoise, client_id}, type, status}, state) do
    Logger.warn("Event #{client_id} #{type} #{status}}")
    {:noreply, state}
  end
end
