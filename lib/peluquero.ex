defmodule Peluquero do
  @moduledoc """
  Application handler for the `Peluquero` application.
  """

  use Application
  use Peluquero.Namer

  require Logger

  @doc false
  def start(_type, args) do
    import Supervisor.Spec, warn: false

    peluquerias = Application.get_env(:peluquero, :peluquerias, [])
    peinados = Application.get_env(:peluquero, :peinados, [])

    Logger.warn(fn -> "✂ Peluquero started:\n  — peluquerias: #{inspect peluquerias}.\n  — peinados: #{inspect peinados}.\n  — args: #{inspect args}.\n" end)

    amqps = case Enum.map(peluquerias, fn {name, settings} ->
              supervisor(Peluquero.Peluqueria,
                          [Keyword.merge(settings, name: name)],
                          id: fqname(Peluquero.Peluqueria, name))
            end) do
              [] -> [supervisor(Peluquero.Peluqueria, [])]
              many -> many
            end

    redises = supervisor(Peluquero.Peinados, [peinados],
                          id: fqname(Peluquero.Peinados, "Procurator"))

    opts = [strategy: :one_for_one, name: fqname(Peluquero.Supervisor, args)]
    Supervisor.start_link([redises | amqps], opts)
  end
end
