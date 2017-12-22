defmodule Peluquero.Tester do
  @moduledoc false
  defmacro __using__(_opts) do
    quote do
      defp purge(list) when is_list(list) do
        Enum.each(list, &purge/1)
      end

      defp purge(module) when is_atom(module) do
        :code.delete(module)
        :code.purge(module)
      end
    end
  end
end

defmodule Peluquero.Test.Bucket do
  @moduledoc """
    The `Bucket` server implementation
  """

  use GenServer

  require Logger

  ##############################################################################

  @doc "Starts the `Bucket` server up"
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_args), do: {:ok, []} |> IO.inspect(label: "⚑ [BUCKET] :: <UP>")

  ##############################################################################

  @spec state() :: any()
  def state(), do: GenServer.call(__MODULE__, :state)

  @spec state!([any()]) :: any()
  def state!(new_state), do: GenServer.cast(__MODULE__, {:state!, new_state})

  @spec put(String.t() | Map.t()) :: any()
  def put(some) when is_map(some), do: GenServer.cast(__MODULE__, {:put, some})
  def put(some) when is_binary(some), do: some |> Jason.decode!() |> put()

  ##############################################################################

  @doc false
  def handle_call(:state, _from, state), do: {:reply, state, state}

  @doc false
  def handle_cast({:put, some}, state), do: {:noreply, [some | state]}

  @doc false
  def handle_cast({:state!, new_state}, _state), do: {:noreply, new_state}

  @doc false
  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state), do: {:noreply, state}
end

ExUnit.start(exclude: :local_only)
