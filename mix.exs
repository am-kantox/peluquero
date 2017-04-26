defmodule Peluquero.Mixfile do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :peluquero,
      version: "0.1.1",
      elixir: "~> 1.4",
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

      {:consul, git: "https://github.com/am-kantox/consul-ex.git"},
      {:httpoison, "~> 0.9"},
      {:yaml_elixir, "~> 1.0"},
      {:json, "~> 0.3"},

      {:credo, "~> 0.7", only: [:dev, :test]},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.11", only: :dev},
      {:mock, "~> 0.2", only: :test}
    ]
  end

  defp description do
    """
    RabbitMQ middleware to plug into exchange chain to transform data.

    Peluquero is reading all the configured source exchanges, passes each payload to the chain of configured transformers and publishes the result to all the configured destination exchanges.

    The transformer might be either a function of arity 1, or a tuple of two atoms, specifying the module and the function of arity 1 within this module. Return value of transformed is used as a new payload, unless transformer returns nil. If this is a case, the payload is left intact.

    Handlers might be added in runtime using Peluquero.handler!/1, that accepts any type of transformers described above. Handlers are appended to the list. Maybe later this function would accept an optional parameter, saying whether the handler should be appended, or prepended.
    """
  end

  defp package do
    [
     name: :peluquero,
     files: ~w|bin lib mix.exs README.md|,
     maintainers: ["Aleksei Matiushkin"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/am-kantox/peluquero",
              "Docs" => "https://hexdocs.pm/peluquero"}]
  end
end
