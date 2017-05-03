defmodule Peluquero.Peluqueria do
  @moduledoc ~S"""
  The supervisor process for the `Peluquero.Actor` and `Peluquero.Rabbit` pair.
  """
  use Supervisor
  use Peluquero.Namer

  @actors  Application.get_env(:peluquero, :actors, [])
  @rabbits Application.get_env(:peluquero, :rabbits, 1)
  @opts    Application.get_env(:peluquero, :opts, [])
  @consul  Application.get_env(:peluquero, :consul, "configuration/macroservices/peluquero")
  @pool    Application.get_env(:peluquero, :pool, [])

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: fqname(opts))
  end

  def init(opts) do
    pool = Keyword.merge([
        actors: [size: 5, max_overflow: 10],
        type: :local],
      opts[:pool] || @pool)

    pool_actor = Keyword.merge(pool[:actors], [
        name: {pool[:type], actor(opts)},
        worker_module: Peluquero.Actor])

    rabbits = Enum.map(1..(opts[:rabbits] || @rabbits), fn idx ->
      worker(Peluquero.Rabbit,
        [[name: opts[:name], opts: opts[:opts] || @opts, consul: opts[:consul] || @consul]],
        id: Module.concat(fqname(Peluquero.Rabbit, opts), "Worker#{idx}"))
    end)

    children = [
      :poolboy.child_spec(actor(opts), pool_actor,
        [name: opts[:name], actors: opts[:actors] || @actors]) | rabbits]

    supervise(children, strategy: :one_for_one)
  end

  ##############################################################################

  defp actor(nil), do: Peluquero.Actor
  defp actor(opts) when is_list(opts), do: fqname(Peluquero.Actor, opts[:name])
  defp actor(name) when is_atom(name) or is_binary(name), do: fqname(Peluquero.Actor, name)

  defp publisher(nil), do: Peluquero.Rabbit
  defp publisher(opts) when is_list(opts), do: fqname(Peluquero.Rabbit, opts[:name])
  defp publisher(name) when is_atom(name) or is_binary(name), do: fqname(Peluquero.Rabbit, name)

  ##############################################################################

  @doc "Adds a handler to the handlers list"
  def handler!(name \\ nil, fun) when is_function(fun, 1) or is_tuple(fun) do
    :poolboy.transaction(actor(name),
      fn(pid) -> GenServer.call(pid, {:handler, fun}) end
    )
  end

  @doc "Adds a handler to the handlers list"
  def shear!(name \\ nil, payload) do
    :poolboy.transaction(actor(name),
      fn(pid) -> GenServer.call(pid, {:shear, payload}) end
    )
  end

  ##############################################################################

  # @doc "Publishes a new message to publisher specified by name"
  def publish!(name \\ nil, payload) do
    Peluquero.Rabbit.publish!(publisher(name), payload)
  end

  @doc "Publishes a new message to publisher specified by name, queue and exchange"
  def publish!(name, queue, exchange, payload) do
    Peluquero.Rabbit.publish!(publisher(name), queue, exchange, payload)
  end

end
