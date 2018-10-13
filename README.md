# ConduitMQTT

An MQTT adapter for [Conduit](https://github.com/conduitframework/conduit).

## Installation

This package can be installed as:

  1. Add `conduit_mqtt` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:conduit_mqtt, "~> 0.1.0"}]
    end
    ```

  2. Ensure `conduit_mqtt` is started before your application:

    ```elixir
    def application do
      [applications: [:conduit_mqtt]]
    end
    ```

## Configuring the Adapter

```elixir
# config/config.exs

config :my_app, MyApp.Broker,
  adapter: ConduitMQTT, connection_opts: [server: {Tortoise.Transport.Tcp, host: 'localhost', port: 1883}]  #TODO IS THIS CORRECT WAY TO GET INTO ADAPTER OPTS?

# Stop lager redirecting :error_logger messages
config :lager, :error_logger_redirect, false

# Stop lager removing Logger's :error_logger handler
config :lager, :error_logger_whitelist, [Logger.ErrorHandler]
```

For the full set of connection_opts, see the docs for underlying library [Tortiose](https://hexdocs.pm/tortoise/connecting_to_a_mqtt_broker.html#connection-handler).


## Configuring a Subscriber

Inside an `incoming` block for a broker, you can define subscriptions to queues. Conduit will route messages on those
topics to your subscribers.

``` elixir
defmodule MyApp.Broker do
  incoming MyApp do
    subscribe :my_subscriber, MySubscriber, from: "rooms/+/temp", qos: 1
    subscribe :my_other_subscriber, MyOtherSubscriber,
      from: "rooms/#",
      prefetch_size: 20
  end
end
```

### Options

* `:from` - The topic filter to subscribe to.
* `:qos` - The quality of service to use for the subscription - defaults to 0.

See [mqtt-overview](https://hexdocs.pm/tortoise/introduction.html#mqtt-overview) for more details on options.

## Configuring a Publisher

Inside an `outgoing` block for a broker, you can define publications to exchanges. Conduit will deliver messages using the
options specified. You can override these options, by passing different options to your broker's `publish/3`.

``` elixir
defmodule MyApp.Broker do
  outgoing do
    publish :something,
      to: "rooms/living-room/temp",
      qos: 1
    publish :something_else,
      to: "rooms/dining-room/temp",
      qos: 1
  end
end
```

### Options

* `:to` - The topic for the message. If the message already has it's destination set, this option will be ignored.
* `:qos` - The quality of service for the publish defaults to 0.


## Local Testing with Docker

verneMQ  docker command for development testing:
```
docker run -p 1883:1883 -e "DOCKER_VERNEMQ_ALLOW_ANONYMOUS=on" -e "DOCKER_VERNEMQ_log.console.level=debug" -it erlio/docker-vernemq:1.5.0
```
## TODO:
- Trim down some of the logging
- Lots of TODOs
- Keyword lists in the GenServer's should probably be maps or normal lists
- add the badges to the readme