defmodule Peluquero.Mixfile do
  use Mix.Project

  def project do
    [
      app: :peluquero,
      version: "0.1.0",
      elixir: "~> 1.5-dev",
      start_permanent: Mix.env == :prod,
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

      {:rabbit_common, "~> 3.6"},
      {:amqp_client, "~> 3.6"},
      {:amqp, "~> 0.2"},
      # {:exredis, "~> 0.2"},
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
end
