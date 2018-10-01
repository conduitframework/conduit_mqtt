defmodule ConduitMQTT.Conn do
  @moduledoc """
  Manages an Tortoise connection
  """
  use Connection
  require Logger

  @reconnect_after_ms 5_000

  def start_link(opts \\ []) do
    Connection.start_link(__MODULE__, opts)
  end

  def init(opts) do
    Process.flag(:trap_exit, true)
    {:connect, :init, %{opts: opts, conn: nil}}
  end

  def handle_call(:conn, _from, %{conn: nil} = status) do
    {:reply, {:error, :disconnected}, status}
  end

  def handle_call(:conn, _from, %{conn: conn} = status) do
    {:reply, {:ok, conn}, status}
  end

  def connect(_, state) do
    client_id = String.slice(UUID.uuid4(:hex), 0, 22)

    connect_opts = Keyword.get(state.opts, :connection_opts, state.opts)

    connect_opts = Keyword.put(connect_opts, :client_id, client_id)
    case Tortoise.Connection.start_link(connect_opts) do
      {:ok, pid} ->
        Logger.info("#{inspect(self())} Connected via MQTT! with client_id:#{client_id}")
        Process.monitor(pid)
        {:ok, %{state | conn: client_id}}

      {:error, reason} ->
        Logger.error("#{inspect(self())} Connection failed via MQTT! #{inspect(reason)}")
        {:backoff, @reconnect_after_ms, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, %{conn: %{pid: conn_pid}} = state)
      when pid == conn_pid do
    Logger.error("#{inspect(self())} Lost MQTT connection, because #{inspect(reason)}")
    Logger.info("#{inspect(self())} Attempting to reconnect...")
    {:connect, :reconnect, %{state | conn: nil}}
  end

  def terminate(_reason, %{conn: nil}), do: :ok

  def terminate(_reason, %{conn: client_id}) do
    Logger.info("#{inspect(self())} MQTT connection terminating")

    Tortoise.Connection.disconnect(client_id)
  catch
    _, _ ->
      :ok
  end
end
