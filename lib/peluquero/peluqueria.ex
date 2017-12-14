defmodule Peluquero.Peluqueria do
  @moduledoc ~S"""
  The supervisor process for the `Peluquero.Actor` and `Peluquero.Rabbit` pair.
  """
  use Supervisor
  use Peluquero.Namer

  require Logger

  @scissors Application.get_env(:peluquero, :scissors, [])
  @rabbits Application.get_env(:peluquero, :rabbits, 1)
  @opts Application.get_env(:peluquero, :opts, [])
  @consul Application.get_env(:peluquero, :consul, nil)
  @rabbit Application.get_env(:peluquero, :rabbit, nil)
  @pool Application.get_env(:peluquero, :pool, [])

  defmodule Chairs do
    @moduledoc false

    use GenServer
    use Peluquero.Namer

    @doc "Adds a middleware to the middlewares list"
    @spec scissors!(String.t | Atom.t, Function.t | Tuple.t) :: any()
    def scissors!(name \\ nil, fun) when is_function(fun, 1) or is_tuple(fun) do
      GenServer.call(fqname(__MODULE__, name), {:scissors, fun})
    end

    @doc "Removes the middleware from the middlewares list"
    @spec blunt!(String.t | Atom.t, Integer.t) :: [Atom.t]
    def blunt!(name \\ nil, count \\ 0) do
      GenServer.call(fqname(__MODULE__, name), {:blunt, count})
    end

    @doc "Retrieves a list of middlewares"
    @spec scissors?(String.t | Atom.t) :: [Function.t | Tuple.t]
    def scissors?(name \\ nil) do
      GenServer.call(fqname(__MODULE__, name), :shavery)
    end

    ############################################################################

    def start_link(opts \\ []) when is_list(opts) do
      GenServer.start_link(__MODULE__, opts[:scissors] || [], name: fqname(opts))
    end

    def init(args), do: {:ok, args}

    def handle_call(:shavery, _from, state),
      do: {:reply, state, state}

    def handle_call({:scissors, fun}, _from, state),
      do: {:reply, :ok, state ++ [fun]}

    def handle_call({:blunt, count}, _from, state) when count == 0,
      do: {:reply, state, []}

    def handle_call({:blunt, count}, _from, state) when count > 0,
      do: with {result, state} <- Enum.split(state, count),
        do: {:reply, result, state}

    def handle_call({:blunt, count}, _from, state) when count < 0,
      do: with {result, state} <- Enum.split(:lists.reverse(state), count),
        do: {:reply, :lists.reverse(result), :lists.reverse(state)}
  end

  ##############################################################################

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: fqname(opts))
  end

  def init(opts) do
    pool =
      Keyword.merge([actors: [size: 5, max_overflow: 10], type: :local], opts[:pool] || @pool)

    pool_actor =
      Keyword.merge(
        pool[:actors],
        name: {pool[:type], actor(opts)},
        worker_module: Peluquero.Actor
      )

    rabbits =
      Enum.map(1..(opts[:rabbits] || @rabbits), fn idx ->
        name =
          opts[:name]
          |> to_string()
          |> Macro.camelize()
          |> Module.concat("Worker#{idx}")

        name = fqname(Peluquero.Rabbit, name)

        worker(
          Peluquero.Rabbit,
          [
            [
              name: name,
              opts: opts[:opts] || @opts,
              consul: opts[:consul] || @consul,
              rabbit: opts[:rabbit] || @rabbit
            ]
          ],
          id: name
        )
      end)

    children = [
      worker(Peluquero.Peluqueria.Chairs, [
        [name: opts[:name], scissors: opts[:scissors] || @scissors]
      ])
      | [:poolboy.child_spec(actor(opts), pool_actor, name: opts[:name]) | rabbits]
    ]

    supervise(children, strategy: :one_for_one)
  end

  ##############################################################################

  defp trim(name) when is_atom(name), do: name |> to_string() |> trim()

  defp trim(<<"Elixir."::binary, _::binary>> = name) when is_binary(name) do
    trim_leading =
      case Module.split(name) do
        ["Peluquero", "Actor" | rest] -> rest
        ["Peluquero", "Rabbit" | rest] -> rest
        ["Peluquero", "Peluqueria" | rest] -> rest
        rest -> rest
      end

    trim_trailing =
      case :lists.reverse(trim_leading) do
        [<<"Worker"::binary, _::binary>> | rest] -> rest
        rest -> rest
      end

    trim_trailing
    |> :lists.reverse()
    |> Module.concat()
  end

  defp trim(name) when is_binary(name), do: name

  defp actor(nil), do: Peluquero.Actor
  defp actor(opts) when is_list(opts), do: actor(opts[:name])
  defp actor(name) when is_atom(name) or is_binary(name), do: fqname(Peluquero.Actor, trim(name))

  defp publishers(name, full \\ false) do
    Peluquera
    |> Supervisor.which_children()
    |> Enum.flat_map(fn
         {mod, _pid, :supervisor, [__MODULE__]} ->
           case fqname(name) do
            ^mod -> Supervisor.which_children(mod)
            _ -> []
           end
         _ -> []
       end)
    |> Enum.map(fn
         {mod, _pid, :worker, [Peluquero.Rabbit]} = child ->
           if full, do: child, else: mod
         _ -> nil
       end)
    |> Enum.reject(& is_nil/1)
  end

  defp publisher(name, number \\ :random)
  defp publisher(name, :random) do
    case publishers(name) do
      [] -> raise(Peluquero.Errors.UnknownTarget, target: name, reason: :notfound)
      list when is_list(list) -> Enum.random(list)
    end
  end
  defp publisher(name, number) when is_integer(number) or is_atom(number),
    do: publisher(name, Integer.to_string(number))
  defp publisher(name, number) when is_binary(number) do
    Enum.find(publishers(name), fn mod ->
      mod
      |> to_string()
      |> String.ends_with?(number)
    end)
  end

  ##############################################################################

  @doc "Adds a middleware to the middlewares list"
  def scissors!(name \\ nil, fun) when is_function(fun, 1) or is_tuple(fun) do
    Peluquero.Peluqueria.Chairs.scissors!(name, fun)
  end

  @doc "Adds a handler to the handlers list"
  def shear!(name \\ nil, payload) do
    :poolboy.transaction(actor(name), fn pid -> GenServer.call(pid, {:shear, payload}) end)
  end

  @doc "Directly publishes a payload to the publisher specified by name, queue and exchange"
  def shear!(name, queue, exchange, payload, routing_key \\ "") do
    :poolboy.transaction(actor(name), fn pid ->
      GenServer.call(pid, {:shear, queue, exchange, payload, routing_key})
    end)
  end

  @doc "Adds a handler to the handlers list"
  def comb!(name \\ nil, payload) do
    :poolboy.transaction(actor(name), fn pid -> GenServer.call(pid, {:comb, payload}) end)
  end

  @doc "Directly publishes a payload to the publisher specified by name, queue and exchange"
  def comb!(name, queue, exchange, payload, routing_key \\ "") do
    :poolboy.transaction(actor(name), fn pid ->
      GenServer.call(pid, {:comb, queue, exchange, payload, routing_key})
    end)
  end

  ##############################################################################

  # @doc "Publishes a new message to publisher specified by name"
  def publish!(name \\ nil, payload) do
    Peluquero.Rabbit.publish!(publisher(name), payload)
  end

  @doc "Publishes a new message to publisher specified by name, queue and exchange"
  def publish!(name, queue, exchange, payload, routing_key \\ "") do
    Peluquero.Rabbit.publish!(publisher(name), queue, exchange, payload, routing_key)
  end
end
