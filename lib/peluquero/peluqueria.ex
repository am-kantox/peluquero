defmodule Peluquero.Peluqueria do
  @moduledoc ~S"""
  The supervisor process for the `Peluquero.Actor` and `Peluquero.Rabbit` pair.
  """
  use Supervisor
  use Peluquero.Namer

  @actors Application.get_env(:peluquero, :actors, [])
  @opts   Application.get_env(:peluquero, :opts, [])
  @consul Application.get_env(:peluquero, :consul, "configuration/macroservices/peluquero")

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: fqname(opts))
  end

  def init(opts) do
    children = [
      worker(Peluquero.Actor,
        [[name: opts[:name], actors: opts[:actors] || @actors]],
        id: fqname(Peluquero.Actor, opts)),
      worker(Peluquero.Rabbit,
        [[name: opts[:name], opts: opts[:opts] || @opts, consul: opts[:consul] || @consul]],
        id: fqname(Peluquero.Rabbit, opts))
    ]
    supervise(children, strategy: :one_for_one)
  end

  ##############################################################################

  @doc "Adds a handler to the handlers list"
  def handler!(name \\ nil, fun) when is_function(fun, 1) or is_tuple(fun),
    do: Peluquero.Actor.handler!(name, fun)

  ##############################################################################

  # @doc "Publishes a new message to rabbit specified by name"
  # def publish!(name \\ nil, payload),
  #   do: Peluquero.Rabbit.publish!(name, payload)

  @doc "Publishes a new message to rabbit specified by name, queue and exchange"
  def publish!(name, queue, exchange, payload),
    do: Peluquero.Rabbit.publish!(name, queue, exchange, payload)

end
