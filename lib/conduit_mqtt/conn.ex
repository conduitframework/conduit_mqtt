defmodule ConduitMQTT.Conn do
  @moduledoc """
  Manages an Tortoise connection
  """
  use GenServer
  require Logger
  alias ConduitMQTT.Util

  ## Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def get_client_id(server) do
    GenServer.call(server, :get_client_id)
  end

  ## Server Callbacks
  def init(opts) do
    #Process.flag(:trap_exit, true) #TODO what does this do?
    #send(self(), :make_connection) #TODO problem is if I make this a message then im not ready when people try to use me, need to block
    {:ok, state} = do_connect(%{opts: opts})
    {:ok, state}
  end

  def handle_info(:make_connection, state) do
    do_connect(state)
    {:noreply, state}
  end

  def handle_call(:get_client_id, _from, state) do
    client_id = get_client_id_from_state(state)
    {:reply, {:ok, client_id}, state}
  end

  defp do_connect(state) do

    client_id = generate_client_id()
    state = put_in(state[:opts][:connection_opts][:client_id], client_id)

    connection_opts = get_connection_opts_from_state(state)
    case Tortoise.Connection.start_link(connection_opts) do
      {:ok, pid} ->
        Logger.info("#{inspect(self())} Trying to connect via MQTT! with client_id:#{client_id}")
        {:ok, state}

      {:error, reason} ->
        Logger.error("#{inspect(self())} Connection failed via MQTT! #{inspect(reason)}")
        {:error, state}
    end
  end

  defp get_client_id_from_state(state) do
    state
    |> get_connection_opts_from_state()
    |> Keyword.get(:client_id)
  end

  defp get_connection_opts_from_state(state) do
    Keyword.get(state.opts, :connection_opts)
  end

  defp generate_client_id() do
    allowed_chars = Enum.concat([?0..?9, ?A..?Z, ?a..?z])
    random_char = fn  -> Enum.random(allowed_chars) end

    Stream.repeatedly(random_char)
    |> Enum.take(22)
    |> List.to_string()
  end
end
