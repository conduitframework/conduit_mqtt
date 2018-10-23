# ConduitMQTT

[![CircleCI](https://img.shields.io/circleci/project/github/conduitframework/conduit_mqtt.svg?style=flat-square)](https://circleci.com/gh/conduitframework/conduit_mqtt)
[![Coveralls](https://img.shields.io/coveralls/conduitframework/conduit_mqtt.svg?style=flat-square)](https://coveralls.io/github/conduitframework/conduit_mqtt)
[![Hex.pm](https://img.shields.io/hexpm/v/conduit_mqtt.svg?style=flat-square)](https://hex.pm/packages/conduit_mqtt)
[![Hex.pm](https://img.shields.io/hexpm/l/conduit_mqtt.svg?style=flat-square)](https://github.com/conduitframework/conduit_mqtt/blob/master/LICENSE.md)
[![Hex.pm](https://img.shields.io/hexpm/dt/conduit_mqtt.svg?style=flat-square)](https://hex.pm/packages/conduit_mqtt)

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
  adapter: ConduitMQTT, connection_opts: [server: {Tortoise.Transport.Tcp, host: 'localhost', port: 1883}]
```

For the full set of connection_opts, see the docs for underlying library [Tortiose](https://hexdocs.pm/tortoise/connecting_to_a_mqtt_broker.html#connection-handler).

NOTE: will and retain have not been tested. They may work by passing through on the opts. Let us know your use cases
or submit a PR

## Configuring Queues

MQTT defines queues on use. Configuring subscribers and publishers is all that's needed.

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


## Supporting Message Attributes and Headers

MQTT 3.1.1 and below do not support a mechanism for message headers.  In order to support conduits headers and attributes
if you need to use these, you need to wrap them into your payload.  Two plugs are provided to help with this

ConduitMQTT.Plug.Wrap and ConduitMQTT.Plug.Unwrap each provide a default method for wrapping and unwrapping headers and
attributes into the payload along with the message body.  You can also pass a wrap_fn and unwrap_fn to them in the opts
for the plug if you would like to override the default functions (you can also write your own plugs that perform a
similar function).

Example pipelines might look as follows:

```elixir
   pipeline :serialize do
     plug Conduit.Plug.Format, content_type: "application/json"
     plug Conduit.Plug.Encode, encoding: "aes256gcm"
     plug ConduitMQTT.Plug.Wrap
     plug Conduit.Plug.Format, content_type: "application/json"
   end
```
The above formats the message body into json, encrypts it, wraps the headers, attributes, and body into map and then
formats that into json for transport. Your pipeline could be simpler.

And the reverse of the above pipeline:

```elixir
   pipeline :deserialize do
     plug Conduit.Plug.Parse, content_type: "application/json"
     plug ConduitMQTT.Plug.Unwrap
     plug Conduit.Plug.Decode, encoding: "aes256gcm"
     plug Conduit.Plug.Parse, content_type: "application/json"
   end
```

## Local Testing with Docker

verneMQ  docker command for development testing:
```
docker run -p 1883:1883 -e "DOCKER_VERNEMQ_ALLOW_ANONYMOUS=on" -e "DOCKER_VERNEMQ_log.console.level=debug" -it erlio/docker-vernemq:1.5.0
```
## TODO:
- Trim down some of the logging
- Lots of TODOs
- Keyword lists in the GenServer's should probably be maps or normal lists
