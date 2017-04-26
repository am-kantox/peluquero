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
  def handler!(fun) when is_function(fun),
    do: GenServer.call(__MODULE__, {:handler, fun})

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
    {:reply, :ok, [fun | state]}
  end

  def handle_cast({:yo, payload}, state) do
    Enum.each(state, fn
      handler when is_function(handler, 1) -> Task.async(fn -> handler.(payload) end)
      {mod, fun} -> Task.async(mod, fun, [payload])
    end)
    {:noreply, state}
  end
end
