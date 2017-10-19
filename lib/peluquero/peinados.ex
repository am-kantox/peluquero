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

  @doc "Retrieves the list of peinados available"
  def children(format \\ :full)

  @doc "Retrieves the list of peinados available"
  def children(:full), do: Supervisor.which_children(Peluquero.Peinados)

  @doc "Retrieves the list of peinados available"
  def children(:short), do: Enum.map(children(:full), fn {name, _, _, _} -> name end)

  @doc "Retrieves the list of peinados available"
  def children(:uniq) do
    :short
    |> children()
    |> Enum.map(&fqparent/1)
    |> Enum.uniq
  end

  @doc "Checks whether the child exists"
  def child?(name), do: Enum.member?(children(:uniq), fqname(Peluquero.Redis, name))

  ##############################################################################

  @doc "Returns true if Peinados has at least one child."
  def active?() do
    %{specs: _specs,
      active: active,
      supervisors: _supervisors,
      workers: _workers} = Supervisor.count_children(Peluquero.Peinados)
    active > 0
  end

  @doc "Retrieves the value by key from the redis, specified by name"
  def get(name \\ nil, key) do
    case Peluquero.Redis.get(publisher(name), key) do
      :undefined -> nil
      whatever -> whatever
    end
  end

  @doc "Sets a new value for the key in the redis, specified by name"
  def set(name \\ nil, key, value) do
    Peluquero.Redis.set(publisher(name), key, value)
  end

  @doc "Deletes the value by key from the redis, specified by name"
  def del(name \\ nil, key) do
    Peluquero.Redis.del(publisher(name), key)
  end

  ##############################################################################

  defp publisher(nil), do: Peluquero.Redis
  defp publisher(opts) when is_list(opts), do: fqname(Peluquero.Redis, opts[:name])
  defp publisher(name) when is_atom(name) or is_binary(name), do: fqname(Peluquero.Redis, name)

end
