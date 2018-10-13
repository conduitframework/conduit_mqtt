defmodule ConduitMQTT.Conn do
  @moduledoc """
  Manages an Tortoise connection
  """
  use GenServer
  require Logger

  ## Client API
  def child_spec([broker: broker, name: name, opts: _] = args) do
    %{
      id: name(broker, name),
      start: {__MODULE__, :start_link, [args]},
      type: :worker
    }
  end

  def name(broker, queue) do
    {Module.concat(broker, Adapter.Sub), queue}
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def get_client_id(server) do
    GenServer.call(server, :get_client_id)
  end

  ## Server Callbacks
  def init(opts) do
    send(self(), :make_connection)
    # {:ok, state} = do_connect(%{opts: opts}) #syncrnous but doesn't help, connection still not ready on return
    {:ok, opts}
  end

  def handle_info(:make_connection, state) do
    {:ok, state} = do_connect(state)
    {:noreply, state}
  end

  def handle_call(:get_client_id, _from, state) do
    client_id = get_client_id_from_state(state)
    {:reply, {:ok, client_id}, state}
  end

  defp do_connect([broker: broker, name: name, opts: opts] = state) do
    client_id = generate_client_id()

    state = put_in(state[:opts][:connection_opts][:client_id], client_id)

    state =
      put_in(
        state[:opts][:connection_opts][:handler],
        {ConduitMQTT.Handler, [client_id: client_id, broker: broker, name: name, opts: opts]}
      )

    connection_opts = get_connection_opts_from_state(state)

    case Tortoise.Connection.start_link(connection_opts) do
      {:ok, _pid} ->
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
    Keyword.get(state[:opts], :connection_opts)
  end

  defp generate_client_id() do
    allowed_chars = Enum.concat([?0..?9, ?A..?Z, ?a..?z])
    random_char = fn -> Enum.random(allowed_chars) end

    random_char
    |> Stream.repeatedly()
    |> Enum.take(22)
    |> List.to_string()
  end
end
