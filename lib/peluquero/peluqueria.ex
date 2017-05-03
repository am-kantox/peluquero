defmodule Peluquero.Peluqueria do
  @moduledoc ~S"""
  The supervisor process for the `Peluquero.Actor` and `Peluquero.Rabbit` pair.
  """
  use Supervisor
  use Peluquero.Namer

  @actors Application.get_env(:peluquero, :actors, [])
  @opts   Application.get_env(:peluquero, :opts, [])
  @consul Application.get_env(:peluquero, :consul, "configuration/macroservices/peluquero")
  @pool   Application.get_env(:peluquero, :pool, [])

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: fqname(opts))
  end

  def init(opts) do
    pool = Keyword.merge([
        rabbit: [size: 5, max_overflow: 10],
        actor: [size: 5, max_overflow: 10],
        type: :local],
      opts[:pool] || @pool)

    pool_actor = Keyword.merge(pool[:actor], [
        name: {pool[:type], actor(opts)},
        worker_module: Peluquero.Actor])

    pool_rabbit = Keyword.merge(pool[:rabbit], [
        name: {pool[:type], rabbit(opts)},
        worker_module: Peluquero.Rabbit])

    children = [
      :poolboy.child_spec(actor(opts), pool_actor,
        [[name: opts[:name], actors: opts[:actors] || @actors]]),
      :poolboy.child_spec(rabbit(opts), pool_rabbit,
        [[name: opts[:name], opts: opts[:opts] || @opts, consul: opts[:consul] || @consul]])]

    supervise(children, strategy: :one_for_one)
  end

  ##############################################################################

  defp actor(nil), do: Peluquero.Actor
  defp actor(opts) when is_list(opts), do: fqname(Peluquero.Actor, opts[:name])
  defp actor(name) when is_binary(name), do: fqname(Peluquero.Actor, name)

  defp rabbit(nil), do: Peluquero.Rabbit
  defp rabbit(opts) when is_list(opts), do: fqname(Peluquero.Rabbit, opts[:name])
  defp rabbit(name) when is_binary(name), do: fqname(Peluquero.Rabbit, name)

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
      fn(pid) -> GenServer.cast(pid, {:shear, payload}) end
    )
  end

  ##############################################################################

  # @doc "Publishes a new message to rabbit specified by name"
  def publish!(name \\ nil, payload) do
    :poolboy.transaction(rabbit(name),
      fn(pid) -> GenServer.cast(pid, {:publish, payload}) end
    )
  end

  @doc "Publishes a new message to rabbit specified by name, queue and exchange"
  def publish!(name, queue, exchange, payload) do
    :poolboy.transaction(rabbit(name),
      fn(pid) -> GenServer.cast(pid, {:publish, queue, exchange, payload}) end
    )
  end

end
