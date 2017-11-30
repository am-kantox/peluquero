defmodule Peluquero.Rabbit do
  @moduledoc false

  defmodule State do
    @moduledoc false
    defstruct name: nil,
              opts: [],
              consul: nil,
              rabbit: nil,
              suckers: [],
              spitters: [],
              kisser: nil

    def known?(%State{} = state, pid), do: not is_nil(lookup(state, pid))

    def lookup(%State{} = state, %AMQP.Channel{} = channel) do
      Enum.find(state.suckers ++ state.spitters, fn
        {^channel, _queue, _exchange} -> true
        _ -> false
      end)
    end

    def lookup(%State{} = state, exchange) when is_binary(exchange) do
      Enum.find(state.suckers ++ state.spitters, fn
        {_, _queue, ^exchange} -> true
        _ -> false
      end)
    end

    def lookup(%State{} = state, pid) when is_pid(pid) do
      Enum.find(state.suckers ++ state.spitters, fn
        {%AMQP.Channel{conn: %AMQP.Connection{pid: ^pid}} = _channel, _queue, _exchange} -> true
        _ -> false
      end)
    end
  end

  use GenServer
  use Peluquero.Namer
  use AMQP

  require Logger

  @ack_upfront Application.get_env(:peluquero, :ack_upfront, false)

  # @joiner "/"

  ### format is: [exchange1: [routing_key: "rates", prefetch_count: 30], exchange2: [], ...]
  # @connection_keys ~w|sources destinations|a
  @prefetch_count "50"
  @max_queue_len "100000"
  @durable false
  @auto_delete false
  @exchange "amq.fanout"
  @queue "peluquero"

  @doc "Shuts the server down"
  def shutdown(name), do: GenServer.cast(fqname(name), :shutdown)

  @doc "Publishes the payload to the queue specified"
  def publish!(name, queue, exchange \\ @exchange, payload) do
    GenServer.cast(fqname(name), {:publish, queue, exchange, payload})
  end

  @doc "Publishes the payload to all the subscribers"
  def publish!(name \\ nil, payload) do
    GenServer.cast(fqname(name), {:publish, payload})
  end

  ##############################################################################

  def init(%State{} = state) do
    state = %State{
      state
      | suckers: Keyword.merge(
          state.opts[:sources] || [],
          connection_details(state.consul, :sources)
        ),
        spitters: Keyword.merge(
          state.opts[:destinations] || [],
          connection_details(state.consul, :destinations)
        )
    }

    rabbit_connect(state)
  end

  def start_link(opts) do
    state = %State{
      name: opts[:name],
      opts: opts[:opts],
      consul: opts[:consul],
      rabbit: opts[:rabbit]
    }

    GenServer.start_link(__MODULE__, state, name: fqname(opts))
  end

  ##############################################################################

  @doc false
  # Task finished {#Reference<0.0.1.6335>, :ok}
  def handle_info({_pid, :ok}, %State{} = state), do: {:noreply, state}

  @doc false
  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, _}, %State{} = state), do: {:noreply, state}

  @doc false
  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, _}, %State{} = state), do: {:stop, :normal, state}

  @doc false
  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, _}, %State{} = state), do: {:noreply, state}

  @doc false
  # Main handler for the delivered message
  def handle_info(
        {
          :basic_deliver,
          payload,
          %{delivery_tag: tag, redelivered: redelivered, exchange: exchange} = _meta
        },
        %State{} = state
      ) do
    with {channel, _, _} <- State.lookup(state, exchange),
         do: consume(state.name, channel, tag, redelivered, payload)

    {:noreply, state}
  end

  # rabbit went down OR one of child tasks is finished
  def handle_info({:DOWN, _, :process, pid, _reason}, %State{} = state) do
    if State.known?(state, pid), do: raise("❤ planned crash to reinit rabbits")
    {:noreply, state}
  end

  ##############################################################################

  def handle_cast(:shutdown, %State{} = state) do
    Enum.each(state.suckers ++ state.spitters, fn {channel, queue, exchange} ->
      Queue.unbind(channel, queue, exchange)
      Queue.delete(channel, queue)
      Channel.close(channel)
    end)

    Channel.close(state.kisser)
    {:noreply, %State{}}
  end

  def handle_cast({:publish, queue, exchange, payload}, %State{} = state) do
    with :ok <- safe_bind(state.kisser, queue, exchange) do
      Logger.debug(fn -> "[✂] :publish: #{inspect([queue, exchange, payload, state.kisser])}" end)
      Basic.publish(state.kisser, exchange, "", payload)
      Queue.unbind(state.kisser, queue, exchange)
    else
      _ ->
        Logger.warn("⚑ error publishing #{inspect(payload)} to #{queue}(#{exchange})")
    end

    {:noreply, state}
  end

  def handle_cast({:publish, payload}, %State{} = state) when is_binary(payload) do
    Enum.each(state.spitters, fn {channel, queue, exchange} ->
      Logger.debug(fn -> "[✂] publishing: #{inspect([channel, queue, exchange])}" end)
      Basic.publish(channel, exchange, "", payload)
    end)

    {:noreply, state}
  end

  def handle_cast({:publish, payload}, %State{} = state),
    do: handle_cast({:publish, JSON.encode!(payload)}, state)

  ##############################################################################

  defp safe_bind(chan, queue, exchange) do
    with :ok <- Exchange.declare(chan, exchange),
      do: Queue.bind(chan, queue, exchange)
  end

  defp boolean_setting("true", _default), do: true
  defp boolean_setting("yes", _default), do: true
  defp boolean_setting(true, _default), do: true
  defp boolean_setting("false", _default), do: false
  defp boolean_setting("no", _default), do: false
  defp boolean_setting(false, _default), do: false
  defp boolean_setting(_value, default), do: default

  defp init_channel(conn, {exchange, settings}, sucker) do
    exchange = "#{exchange}"
    durable = boolean_setting(settings[:durable], @durable)
    auto_delete = boolean_setting(settings[:auto_delete], @auto_delete)
    prefetch_count =
      case settings[:prefetch_count] || @prefetch_count do
        b when is_binary(b) -> String.to_integer(b)
        i when is_integer(i) -> i
      end
    arguments = extract_arguments(settings)

    {direct_or_fanout, queue_params} =
      if settings[:routing_key] do
        {:direct, [routing_key: settings[:routing_key]]}
      else
        {:fanout, []}
      end

    with {:ok, channel} <- Channel.open(conn),
         queue <- settings[:queue] || exchange <> "." <> @queue <> "." <> nodes_hash() do
      # set `prefetch_count` param for consumers
      if sucker, do: Basic.qos(channel, prefetch_count: prefetch_count)

      Logger.debug(fn -> "[✂] declare queue: #{inspect([sucker, channel, queue])}" end)
      Queue.declare(
        channel,
        queue,
        durable: durable,
        auto_delete: auto_delete,
        arguments: arguments
      )

      apply(Exchange, direct_or_fanout, [channel, exchange, [durable: durable]])

      if sucker do
        Queue.bind(channel, queue, exchange, queue_params)
        {:ok, _consumer_tag} = Basic.consume(channel, queue)
      end

      {channel, queue, exchange}
    end
  end

  defp rabbit_connect(%State{} = state) do
    case Connection.open(connection_params(state)) do
      {:ok, conn} ->
        Logger.info(fn -> "☆ Rabbit: #{inspect(conn)}" end)

        # get notifications when the connection goes down
        Process.monitor(conn.pid)

        state = %State{
          state
          | kisser: with({:ok, channel} <- Channel.open(conn), do: channel),
            suckers: Enum.map(state.suckers, &init_channel(conn, &1, true)),
            spitters: Enum.map(state.spitters, &init_channel(conn, &1, false))
        }

        Logger.warn(fn -> "★ Rabbit: #{inspect(state)}" end)

        {:ok, state}

      {:error, reason} ->
        Logger.warn(fn ->
          "⚐ Rabbit error, reason: #{inspect(reason)}, state: #{inspect(state)}"
        end)

        Process.sleep(1000)
        rabbit_connect(state)
    end
  end

  ##############################################################################

  defp consume(name, channel, tag, redelivered, payload) do
    Logger.debug(fn -> "[✂] consume: #{inspect([name, channel, tag, redelivered, payload])}" end)
    try do
      name
      |> handle_message_chain(channel, tag, redelivered, payload, ack_upfront: @ack_upfront)
      |> Enum.each(fn {mod, fun, args} -> Kernel.apply(mod, fun, args) end)

      Logger.debug(fn ->
        "[✎ #{name}] rabbit.consume in #{inspect(channel)}] #{inspect(payload)}"
      end)
    rescue
      exception ->
        # Requeue unless it's a redelivered message.
        # This means we will retry consuming a message once in case of exception
        # before we give up and have it moved to the error queue
        Logger.error(fn ->
          "[⚑ #{name}] #{inspect(exception)} (while understanding #{inspect(payload)})"
        end)

        Basic.reject(channel, tag, requeue: not redelivered)
    end
  end

  defp handle_message_chain(name, channel, tag, _redelivered, payload, ack_upfront: true) do
    [
      {Task, :async, [Basic, :ack, [channel, tag]]},
      {Peluquero.Peluqueria, :shear!, [name, payload]}
    ]
  end

  defp handle_message_chain(name, channel, tag, redelivered, payload, ack_upfront: false) do
    name
    |> handle_message_chain(channel, tag, redelivered, payload, ack_upfront: true)
    |> :lists.reverse()
  end

  ##############################################################################

  defp connection_params(%State{rabbit: rabbit}) when not is_nil(rabbit), do: rabbit

  defp connection_params(%State{consul: consul}) when not is_nil(consul) do
    case Peluquero.Utils.consul(consul, ~w|rabbit|) do
      [] ->
        []

      rabbit ->
        [
          host: rabbit[:host],
          port: String.to_integer(rabbit[:port]),
          virtual_host: rabbit[:virtual_host],
          username: rabbit[:user],
          password: rabbit[:password]
        ]
    end
  end

  defp connection_params(_) do
    raise "Either consul or rabbit must be set in config.exs"
  end

  defp connection_details(nil, _), do: []

  defp connection_details(consul, type) do
    Peluquero.Utils.consul(consul, Atom.to_string(type))
  end

  defp nodes_hash() do
    names =
      [node() | Node.list()]
      |> Enum.map(&Atom.to_string/1)
      |> Enum.sort()
      |> Enum.join()

    :md5
    |> :crypto.hash(names)
    |> Base.encode16()
  end

  defp extract_arguments(settings) do
    case settings[:x_max_length]
         |> to_string()
         |> Integer.parse() do
      {value, ""} -> [{"x-max-length", value}]
      {_, _} -> [{"x-max-length", @max_queue_len}]
      :error -> []
    end
  end
end
