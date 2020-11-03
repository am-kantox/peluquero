defmodule Peluquera do
  @moduledoc ~S"""
  The top-level supervisor process that allows to use `Peluquero` inside the
    main application supervision tree rather than as a bare application.
  """
  use Supervisor
  use Peluquero.Namer

  require Logger

  ############################################################################

  @doc false
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: fqname(opts))
  end

  @doc false
  def init(args) do
    peluquerias = Application.get_env(:peluquero, :peluquerias, [])
    peinados = Application.get_env(:peluquero, :peinados, [])
    rabbit = Application.get_env(:peluquero, :rabbit, nil)

    Logger.warn(fn ->
      "✂ Peluquero started:\n" <>
        "   — peluquerias: #{inspect(peluquerias)}.\n" <>
        "   — default rabbit: #{inspect(rabbit)}.\n" <>
        "   — peinados: #{inspect(peinados)}.\n" <> "   — args: #{inspect(args)}.\n\n"
    end)

    amqps =
      peluquerias
      |> Enum.map(&spec_for_peluqueria/1)
      |> case do
        [] -> [{Peluquero.Peluqueria, []}]
        many -> many
      end

    redises = spec_for_peinado({"Procurator", peinados})

    Supervisor.init([redises | amqps], strategy: :one_for_one)
  end

  def suicide, do: GenServer.cast(__MODULE__, :suicide)

  ##############################################################################

  defp spec_for_peluqueria({name, settings}) do
    %{
      id: fqname(Peluquero.Peluqueria, name),
      start: {Peluquero.Peluqueria, :start_link, [Keyword.merge(settings, name: name)]},
      restart: :permanent,
      type: :supervisor
    }
  end

  defp spec_for_peinado({name, peinados}) do
    %{
      id: fqname(Peluquero.Peinados, name),
      start: {Peluquero.Peinados, :start_link, [peinados]},
      restart: :permanent,
      type: :supervisor
    }
  end

  def handle_cast(:suicide, _state) do
    raise("❤ planned crash to reinit rabbits")
  end
end
