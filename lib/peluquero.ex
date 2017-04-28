defmodule Peluquero do
  @moduledoc """
  Application handler for the `Peluquero` application.
  """

  use Application
  use Peluquero.Namer

  require Logger

  @peluquerias Application.get_env(:peluquero, :peluquerias, [])

  @doc false
  def start(_type, args) do
    import Supervisor.Spec, warn: false

    Logger.warn(fn -> "✂ Peluquero started with peluquerias: #{inspect @peluquerias}. Args passed: #{inspect args}" end)

    children =  case Enum.map(@peluquerias, fn {name, settings} ->
                  supervisor(Peluquero.Peluqueria,
                              [Keyword.merge(settings, name: name)],
                              id: fqname(Peluquero.Peluqueria, name))
                end) do
                  [] -> [supervisor(Peluquero.Peluqueria, [])]
                  many -> many
                end

    opts = [strategy: :one_for_one, name: fqname(Peluquero.Supervisor, args)]
    Supervisor.start_link(children, opts)
  end
end
