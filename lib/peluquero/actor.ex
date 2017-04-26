defmodule Peluquero.Actor do
  @moduledoc false

  use GenServer

  require Logger

  ##############################################################################

  @doc "Starts the server up"
  def start_link(handlers \\ []) do
    GenServer.start_link(__MODULE__, handlers, name: __MODULE__)
  end

  @doc "Adds a handler to the handlers list"
  def handler!(fun) when is_function(fun, 1),
    do: GenServer.call(__MODULE__, {:handler, fun})

  @doc "Adds a handler to the handlers list"
  def handler!({mod, fun}) when is_atom(mod) and is_atom(fun),
    do: GenServer.call(__MODULE__, {:handler, {mod, fun}})

  @doc "Adds a handler to the handlers list"
  def yo!(payload),
    do: GenServer.cast(__MODULE__, {:yo, payload})

  ##############################################################################

  @doc false
  # Task finished {#Reference<0.0.1.6335>, :ok}
  def handle_info({_pid, _payload}, state), do: {:noreply, state}

  @doc false
  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state), do: {:noreply, state}

  ##############################################################################

  def handle_call({:handler, fun}, _from, state) do
    {:reply, :ok, state ++ [fun]}
  end

  def handle_cast({:yo, payload}, state) do
    Task.async(fn ->
      state
      |> Enum.reduce(payload, fn
           {mod, fun}, payload -> apply(mod, fun, [payload]) || payload
           handler, payload when is_function(handler, 1) -> handler.(payload) || payload
         end)
      |> Peluquero.Rabbit.publish!
    end)
    {:noreply, state}
  end
end
