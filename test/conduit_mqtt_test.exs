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

  test "plug formats and decodes extended payload" do
    message =
      %Conduit.Message{}
      |> put_body("test")
      |> put_created_by("jeremy")
      |> put_header("header1", "header1 value")
      |> put_header("header2", true)
      |> put_header("header3", 3)
      |> ConduitMQTT.Plug.FormatExtendedPayload.run()

    decoded =
      message
      |> ConduitMQTT.Plug.ParseExtendedPayload.run()

    assert decoded.body == "test"
    assert decoded.created_by == "jeremy"
    assert get_header(decoded, "header1") == "header1 value"
    assert get_header(decoded, "header2") == true
    assert get_header(decoded, "header3") == 3
  end

  test "plug formats and decodes extended payload through broker" do
    message =
      %Conduit.Message{}
      |> put_body("test")
      |> put_created_by("jeremy")
      |> put_header("header1", "header1 value")
      |> put_header("header2", true)
      |> put_header("header3", 3)
      |> put_destination("foo/bar1")
      |> ConduitMQTT.Plug.FormatExtendedPayload.run()

    ConduitMQTT.publish(Broker, message, [], qos: 2, retain: false, timeout: 100)

    assert_receive {:broker, received_message}

    decoded =
      received_message
      |> ConduitMQTT.Plug.ParseExtendedPayload.run()

    Logger.info("decoded #{inspect(decoded)}")

    assert decoded.body == "test"
    assert decoded.created_by == "jeremy"
    assert get_header(decoded, "header1") == "header1 value"
    assert get_header(decoded, "header2") == true
    assert get_header(decoded, "header3") == 3

    # topic pattern
    assert decoded.source == ["foo", "bar1"]
    assert get_header(decoded, "routing_key") == "foo/bar1"
  end
end
