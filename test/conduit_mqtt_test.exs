defmodule ConduitMQTTTest do
  @moduledoc false
  use ExUnit.Case, async: false
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
      ConduitMQTT.Meta.get_broker_status(Broker) == :up &&
        ConduitMQTT.Meta.get_broker_status(OtherBroker) == :up
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

  # TODO test both brokers getting same message and message from one broker to the other
end
