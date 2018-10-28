defmodule ConduitMQTTTest do
  @moduledoc false
  use ExUnit.Case, async: false
  import Conduit.Message
  require Logger

  defmodule Broker do
    @moduledoc false
    def receives(_name, message) do
      Logger.info("Broker recieved #{inspect(message)}")
      send(ConduitMQTTTest, {:broker, message})

      message
    end
  end

  defmodule OtherBroker do
    @moduledoc false
    def receives(_name, message) do
      Logger.info("Other broker recieved #{inspect(message)}")
      send(ConduitMQTTTest, {:broker, message})

      message
    end
  end

  @subscribers %{queue_test: [from: "foo/bar1", qos: 0], queue_test2: [from: "foo/bar2", qos: 0]}

  setup_all do
    opts = Application.get_env(:conduit, ConduitMQTTTest)
    ConduitMQTT.start_link(Broker, [], @subscribers, opts)
    ConduitMQTT.start_link(OtherBroker, [], %{}, opts)

    ConduitMQTT.Util.wait_until(fn ->
      ConduitMQTT.Meta.get_broker_status(Broker) == :up && ConduitMQTT.Meta.get_broker_status(OtherBroker) == :up
    end)

    :ok
  end

  setup do
    Process.register(self(), ConduitMQTTTest)

    :ok
  end

  test "a sent message can be received" do
    import Conduit.Message

    message =
      %Conduit.Message{}
      # topic
      |> put_destination("foo/bar1")
      |> put_body("test")

    ConduitMQTT.publish(Broker, message, [], qos: 2, retain: false, timeout: 50)

    assert_receive {:broker, received_message}

    # topic pattern
    assert received_message.source == ["foo", "bar1"]
    assert get_header(received_message, "routing_key") == "foo/bar1"
    assert received_message.body == "test"
  end

  test "can run two adapters at the same time" do
    import Conduit.Message

    message =
      %Conduit.Message{}
      |> put_destination("foo/bar1")
      |> put_body("test")

    ConduitMQTT.publish(Broker, message, [], [])
    ConduitMQTT.publish(OtherBroker, message, [], [])

    assert_receive {:broker, _}
    assert_receive {:broker, _}
  end

  test "broker recovers from terminating all clients and recieves a message" do
    clients = ConduitMQTT.Meta.get_clients(Broker)
    Enum.each(clients, fn [client_id, _] -> Tortoise.Connection.disconnect(client_id) end)

    ConduitMQTT.Util.wait_until(fn -> ConduitMQTT.Meta.get_broker_status(Broker) == :up end)

    message =
      %Conduit.Message{}
      |> put_destination("foo/bar1")
      |> put_body("test")

    ConduitMQTT.publish(Broker, message, [], [])

    assert_receive {:broker, _}
  end

  test "publish with headers but no wrapper through broker raises error" do
    message =
      %Conduit.Message{}
      |> put_body("test")
      |> put_created_by("jeremy")
      |> put_header("header1", "header1 value")
      |> put_header("header2", true)
      |> put_header("header3", 3)
      |> put_destination("foo/bar1")
      |> Conduit.Plug.Format.run(content_type: "application/json")

    assert_raise ConduitMQTT.NeedsWrappingError, fn ->
      ConduitMQTT.publish(Broker, message, [], qos: 2, retain: false, timeout: 100)
    end
  end

  test "publish with headers but no wrapper through broker ignores error with flag set" do
    message =
      %Conduit.Message{}
      |> put_body("test")
      |> put_created_by("jeremy")
      |> put_header("header1", "header1 value")
      |> put_header("header2", true)
      |> put_header("header3", 3)
      |> put_destination("foo/bar1")
      |> Conduit.Plug.Format.run(content_type: "application/json")

    :ok = ConduitMQTT.publish(Broker, message, [ignore_needs_wrapping: true], qos: 2, retain: false, timeout: 100)
  end
end
