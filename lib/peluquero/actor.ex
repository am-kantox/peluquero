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

  def init(args), do: {:ok, args}

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

  @doc false
  def handle_info({:DOWN, _ref, :process, _pid, :shutdown}, state), do: {:noreply, state}

  ##############################################################################

  # GenServer.cast
  defp smart_payload(:ok, payload), do: payload
  # explicitly discarded FIXME NEEDED?
  defp smart_payload(nil, payload), do: payload
  defp smart_payload(%{} = result, _payload), do: result

  defp smart_payload(result, payload) when is_binary(result) do
    case Jason.decode(result) do
      {:ok, %{} = decoded} ->
        decoded

      {:error, reason} ->
        raise(Peluquero.Errors.UnknownTarget, target: {result, payload}, reason: reason)
    end
  end

  defp smart_payload(garbage, payload),
    do: raise(Peluquero.Errors.UnknownTarget, target: {garbage, payload}, reason: :scissors)

  defp reduce_payload(name, payload) do
    name
    |> Peluquero.Peluqueria.Chairs.scissors?()
    |> Enum.reduce(payload, fn
      {mod, fun}, payload ->
        mod
        |> apply(fun, [payload])
        |> smart_payload(payload)

      handler, payload when is_function(handler, 1) ->
        smart_payload(handler.(payload), payload)

      anything, _payload ->
        raise(Peluquero.Errors.UnknownTarget, target: anything, reason: :scissors_settings)
    end)
  end

  def handle_call({:shear, payload}, _from, state) do
    response =
      Peluquero.Peluqueria.publish!(
        state[:name],
        reduce_payload(state[:name], payload)
      )

    {:reply, response, state}
  end

  def handle_call({:shear, queue, exchange, payload, routing_key}, _from, state) do
    response =
      Peluquero.Peluqueria.publish!(
        state[:name],
        queue,
        exchange,
        reduce_payload(state[:name], payload),
        routing_key
      )

    {:reply, response, state}
  end

  def handle_call({:comb, payload}, _from, state) do
    response = Peluquero.Peluqueria.publish!(state[:name], payload)

    {:reply, response, state}
  end

  def handle_call({:comb, queue, exchange, payload, routing_key}, _from, state) do
    response = Peluquero.Peluqueria.publish!(state[:name], queue, exchange, payload, routing_key)

    {:reply, response, state}
  end
end
