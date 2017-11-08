defmodule Peluquero.Actor do
  @moduledoc false

  use GenServer
  use Peluquero.Namer

  require Logger

  ##############################################################################

  @doc "Starts the server up"
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  # @spec handler!((Atom.t | String.t | nil), Function.t) :: :ok
  # def handler!(name \\ nil, fun)
  #
  # @doc "Adds a handler to the handlers list"
  # def handler!(name, fun) when is_function(fun, 1),
  #   do: GenServer.call(fqname(name), {:handler, fun})
  #
  # @doc "Adds a handler to the handlers list"
  # def handler!(name, {mod, fun}) when is_atom(mod) and is_atom(fun),
  #   do: GenServer.call(fqname(name), {:handler, {mod, fun}})
  #
  # @doc "Adds a handler to the handlers list"
  # def shear!(name \\ nil, payload),
  #   do: GenServer.cast(fqname(name), {:shear, payload})

  ##############################################################################

  @doc false
  # Task finished {#Reference<0.0.1.6335>, :ok}
  def handle_info({_pid, _payload}, state), do: {:noreply, state}

  @doc false
  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state), do: {:noreply, state}

  ##############################################################################

  def handle_call({:shear, payload}, _from, state) do
    task = Task.async(fn ->
      Peluquero.Peluqueria.publish!(
        state[:name],
        Enum.reduce(Peluquero.Peluqueria.Chairs.scissors?(state[:name]), payload, fn
          {mod, fun}, payload -> apply(mod, fun, [payload]) || payload
          handler, payload when is_function(handler, 1) -> handler.(payload) || payload
        end))
    end)
    {:reply, task, state}
  end
end
