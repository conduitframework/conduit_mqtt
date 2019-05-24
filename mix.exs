defmodule ConduitMQTT.Mixfile do
  use Mix.Project

  def project do
    [
      app: :conduit_mqtt,
      version: "0.1.0",
      elixir: "~> 1.3",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "ConduitMQTT",
      source_url: "https://github.com/conduitframework/conduit_mqtt",
      homepage_url: "https://hexdocs.pm/conduit_mqtt",
      docs: docs(),

      # Package
      description: "MQTT adapter for Conduit.",
      package: package(),
      dialyzer: [flags: ["-Werror_handling", "-Wrace_conditions"]],

      # Coveralls
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.circle": :test],
      aliases: [publish: ["hex.publish", &git_tag/1]]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [extra_applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:tortoise, "~> 0.9.1"},
      {:connection, "~> 1.0"},
      {:poolboy, "~> 1.5"},
      {:conduit, "~> 0.12.8"},
      {:ex_doc, "~> 0.19", only: :dev},
      {:dialyxir, "~> 0.4", only: :dev},
      {:junit_formatter, "~> 2.0", only: :test},
      {:excoveralls, "~> 0.5", only: :test},
      {:credo, "~> 1.0", only: [:dev, :test]}
    ]
  end

  defp package do
    [
      name: :conduit_mqtt,
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Allen Madsen", "Jeremy Isikoff"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => "https://github.com/conduitframework/conduit_mqtt",
        "Docs" => "https://hexdocs.pm/conduit_mqtt"
      }
    ]
  end

  defp docs do
    [main: "readme", project: "ConduitMQTT", extra_section: "Guides", extras: ["README.md"], assets: ["assets"]]
  end

  defp git_tag(_args) do
    tag = "v" <> Mix.Project.config()[:version]
    System.cmd("git", ["tag", tag])
    System.cmd("git", ["push", "origin", tag])
  end
end
