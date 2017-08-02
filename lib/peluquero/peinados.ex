defmodule Peluquero.Peinados do
  @moduledoc ~S"""
  The supervisor process for the `Peluquero.Redis` instances.
  """
  use Supervisor
  use Peluquero.Namer

  @consul   Application.get_env(:peinado, :consul, nil)

  def start_link(peinados \\ []) do
    Supervisor.start_link(__MODULE__, peinados, name: __MODULE__)
  end

  def init(peinados) do
    children = peinados
               |> Enum.with_index
               |> Enum.map(fn {peinado, idx} ->
      {name, settings} = case peinado do
                           {name, settings} -> {name, settings}
                           name -> {name, []}
                         end
      worker(Peluquero.Redis,
        [[name: name, consul: settings[:consul] || @consul, opts: settings]],
        id: Module.concat(fqname(Peluquero.Redis, name), "Worker#{idx}"))
    end)

    supervise(children, strategy: :one_for_one)
  end

  ##############################################################################

  defp publisher(nil), do: Peluquero.Redis
  defp publisher(opts) when is_list(opts), do: fqname(Peluquero.Redis, opts[:name])
  defp publisher(name) when is_atom(name) or is_binary(name), do: fqname(Peluquero.Redis, name)

  ##############################################################################

  # @doc "Retrieves the value by key from the redis, specified by name"
  def set(name \\ nil, key, value) do
    Peluquero.Redis.set(publisher(name), key, value)
  end

  # @doc "Sets a new value for the key in the redis, specified by name"
  def get(name \\ nil, key) do
    Peluquero.Redis.get(publisher(name), key)
  end
end
