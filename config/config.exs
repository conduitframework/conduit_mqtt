# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

if Mix.env() == :test do
  config :conduit, ConduitMQTTTest, connection_opts: [server: {Tortoise.Transport.Tcp, host: 'localhost', port: 1883}]
end
