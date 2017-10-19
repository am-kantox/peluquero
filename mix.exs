defmodule Peluquero.Mixfile do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :peluquero,
      version: "0.6.1",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :amqp], mod: {Peluquero, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gen_stage, "~> 0.11"},

      {:rabbit_common, "~> 3.5"},
      {:amqp_client, "~> 3.5"},
      {:amqp, "~> 0.2"},
      {:exredis, "~> 0.2"},
      {:poolboy, "~> 1.5"},

      {:consul, "~> 1.1"},
      {:httpoison, "~> 0.9"},
      {:yaml_elixir, "~> 1.0"},
      {:json, "~> 1.0"},

      {:credo, "~> 0.7", only: [:dev, :test]},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.11", only: :dev},
      {:mock, "~> 0.3", only: :test}
    ]
  end

  defp description do
    """
    RabbitMQ middleware to plug into exchange chain to transform data.

    Peluquero is reading all the configured source exchanges, transforms and publishes to all destination exchanges.

    Transformers might be added in runtime using `Peluquero.handler!/1`.
    """
  end

  defp package do
    [
     name: :peluquero,
     files: ~w|lib mix.exs README.md|,
     maintainers: ["Aleksei Matiushkin"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/am-kantox/peluquero",
              "Docs" => "https://hexdocs.pm/peluquero"}]
  end
end
