defmodule ConduitMQTTTest do
  @moduledoc false
  use ExUnit.Case, async: false

  defmodule Broker do
    @moduledoc false
    def receives(_name, message) do
      send(ConduitMQTTTest, {:broker, message})

      message
    end
  end

  defmodule OtherBroker do
    @moduledoc false
    def receives(_name, message) do
      send(ConduitMQTTTest, {:broker, message})

      message
    end
  end

  setup_all do
    opts = Application.get_env(:conduit, ConduitMQTTTest)
    ConduitMQTT.start_link(Broker, @topology, @subscribers, opts)
    ConduitMQTT.start_link(OtherBroker, [], %{}, opts)

    ConduitMQTT.Util.wait_until(fn ->
      ConduitMQTT.Meta.get_setup_status(Broker) == :complete &&
        ConduitMQTT.Meta.get_setup_status(OtherBroker) == :complete
    end)

    :ok
  end

  setup do
    Process.register(self(), ConduitMQTTTest)

    :ok
  end

  test "can make a connection at all" do
    Tortoise.Supervisor.start_child(
      client_id: "my_client_id",
      handler: {Tortoise.Handler.Logger, []},
      server: {Tortoise.Transport.Tcp, host: 'localhost', port: 1883},
      subscriptions: [{"foo/bar", 0}])

    Tortoise.publish("my_client_id", "foo/bar", "Hello from the World of Tomorrow !", qos: 0)
  end

  test "can make a connection with opts" do
    opts = Application.get_env(:conduit, ConduitMQTTTest)
    |> Keyword.get(:connection_opts)
    |> Keyword.put(:client_id, "blah1")
    |> Tortoise.Supervisor.start_child()
  end

  test "a sent message can be received" do
    import Conduit.Message

    message =
      %Conduit.Message{}
      |> put_destination("event/test")
      |> put_body("test")


    ConduitMQTT.publish(Broker, message, [], [])

    assert_receive {:broker, received_message}

    assert received_message.source == "queue/test"
    assert get_header(received_message, "routing_key") == "event/test"
    assert received_message.body == "test"
  end

end
