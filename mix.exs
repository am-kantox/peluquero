defmodule Peluquero.Mixfile do
  @moduledoc false
  use Mix.Project

  @app :peluquero
  # @app_name "Peluquero"
  @version "0.99.9"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :amqp],
      # [name: Application]}
      mod: {Peluquero, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gen_stage, "~> 0.14"},
      {:rabbit_common, "~> 3.7"},
      {:amqp_client, "~> 3.7"},
      {:amqp, "~> 1.0 or ~> 1.1"},
      {:exredis, "~> 0.2"},
      {:poolboy, "~> 1.5"},
      {:consul, "~> 1.1"},
      {:httpoison, "~> 0.9 or ~> 1.2"},
      {:yaml_elixir, "~> 2.0"},
      {:jason, "~> 1.0"},
      {:credo, "~> 1.0", only: [:dev, :test]},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.11", only: :dev},
      {:mock, "~> 0.3", only: :test},
      {:stream_data, "~> 0.4", only: :test}
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
      links: %{
        "GitHub" => "https://github.com/am-kantox/#{@app}",
        "Docs" => "https://hexdocs.pm/#{@app}"
      }
    ]
  end

  defp docs() do
    [
      # main: @app_name,
      main: "intro",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/#{@app}",
      logo: "documentation/logo-69x60.png",
      source_url: "https://github.com/am-kantox/#{@app}",
      extras: [
        "documentation/Intro.md",
        "documentation/GettingStarted.md"
      ],
      groups_for_modules: [
        # Peluquero

        "Entry points": [
          Peluquero,
          Peluquera
        ],
        Internals: [
          Peluquero.Peinados,
          Peluquero.Peluqueria,
          Peluquero.Peluqueria.Chairs,
          Peluquero.Utils
        ],
        Exceptions: [
          Peluquero.Errors.UnknownTarget
        ]
      ]
    ]
  end
end
