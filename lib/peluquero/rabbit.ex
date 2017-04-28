defmodule Peluquero.Rabbit do
  @moduledoc false

  defmodule State do
    @moduledoc false
    defstruct name: nil, opts: [], consul: nil,
              suckers: [], spitters: [], kisser: nil

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

  @joiner "/"

  ### format is: [exchange1: [routing_key: "rates", prefetch_count: 30], exchange2: [], ...]
  # @connection_keys ~w|sources destinations|a
  @prefetch_count 50
  @exchange "amq.fanout"
  @queue "peluquero"

  @doc "Shuts the server down"
  def shutdown(name), do: GenServer.cast(fqname(name), :shutdown)

  @doc "Publishes the payload to the queue specified"
  def publish!(name, queue, exchange \\ @exchange, payload),
    do: GenServer.cast(fqname(name), {:publish, queue, exchange, payload})

  @doc "Publishes the payload to all the subscribers"
  def publish!(name \\ nil, payload),
    do: GenServer.cast(fqname(name), {:publish, payload})

  ##############################################################################

  def init(%State{} = state) do
    state = %State{state |
      suckers: Keyword.merge(state.opts[:sources] || [], connection_details(state.consul, :sources)),
      spitters: Keyword.merge(state.opts[:destinations] || [], connection_details(state.consul, :destinations))
    }
    rabbit_connect(state)
  end

  def start_link(opts) do
    state = %State{name: opts[:name], opts: opts[:opts], consul: opts[:consul]}
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
  def handle_info({:basic_deliver, payload, %{
      delivery_tag: tag, redelivered: redelivered, exchange: exchange} = _meta},
      %State{} = state) do
    with {channel, _, _} <- State.lookup(state, exchange),
      do: consume(state.name, channel, tag, redelivered, payload)
    {:noreply, %State{} = state}
  end

  # rabbit went down OR one of child tasks is finished
  def handle_info({:DOWN, _, :process, pid, _reason}, %State{} = state) do
    if State.known?(state, pid), do: raise "❤ planned crash to reinit rabbits"
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
    with {:ok, _q} <- Queue.declare(state.kisser, queue, durable: true, auto_delete: false),
          :ok <- Exchange.declare(state.kisser, exchange),
          :ok <- Queue.bind(state.kisser, queue, exchange) do
        Basic.publish(state.kisser, exchange, "", payload)
        Queue.unbind(state.kisser, queue, exchange)
    else
      _ ->
        Logger.warn(fn -> "⚑ error publishing #{inspect payload} to #{queue}(#{exchange})" end)
    end
    {:noreply, state}
  end

  def handle_cast({:publish, payload}, %State{} = state) when is_binary(payload) do
    Enum.each(state.spitters, fn {channel, _queue, exchange} ->
      Basic.publish(channel, exchange, "", payload)
    end)
    {:noreply, state}
  end
  def handle_cast({:publish, payload}, %State{} = state),
    do: handle_cast({:publish, JSON.encode!(payload)}, state)

  ##############################################################################

  defp init_channel(conn, {exchange, settings}, sucker) do
    exchange = "#{exchange}"
    with {:ok, channel} <- Channel.open(conn),
          queue <- exchange <> "." <> (settings[:queue] || @queue) do

      # set `prefetch_count` param for consumers
      if sucker do
        Basic.qos(channel, prefetch_count: String.to_integer(settings[:prefetch_count]) || @prefetch_count)
      end

      Queue.declare(channel, queue, durable: false, auto_delete: true)
      apply(Exchange,
            (if settings[:routing_key], do: :direct, else: :fanout),
            [channel, exchange, [durable: false]])

      if sucker do
        Queue.bind(channel, queue, exchange, routing_key: settings[:routing_key])
        {:ok, _consumer_tag} = Basic.consume(channel, queue)
      end
      {channel, queue, exchange}
    end
  end

  defp rabbit_connect(%State{} = state) do
    case Connection.open(connection_params(state.consul)) do
      {:ok, conn} ->
        Logger.info(fn -> "☆ Rabbit: #{inspect conn}" end)

        # get notifications when the connection goes down
        Process.monitor(conn.pid)

        state = %State{state |
          kisser: (with {:ok, channel} <- Channel.open(conn), do: channel),
          suckers: Enum.map(state.suckers, &init_channel(conn, &1, true)),
          spitters: Enum.map(state.spitters, &init_channel(conn, &1, false))
        }

        Logger.warn(fn -> "★ Rabbit: #{inspect state}" end)

        {:ok, state}

      {:error, reason} ->
        Logger.warn(fn -> "⚐ Rabbit error, reason: #{inspect reason}" end)
        Process.sleep(1000)
        rabbit_connect(state)
    end
  end

  ##############################################################################

  defp consume(name, channel, tag, redelivered, payload) do
    try do
      Peluquero.Actor.yo!(name, payload)
      Logger.debug(fn -> "[✎ #{name}] rabbit.consume in #{inspect channel}] #{inspect payload}" end)
      Task.async(Basic, :ack, [channel, tag])
    rescue
      exception ->
        # Requeue unless it's a redelivered message.
        # This means we will retry consuming a message once in case of exception
        # before we give up and have it moved to the error queue
        Logger.error(fn -> "[⚑ #{name}] #{inspect exception} (while understanding #{inspect payload})" end)
        Basic.reject channel, tag, requeue: not redelivered
    end
  end

  ##############################################################################

  def consul(root, path) when is_list(path),
    do: consul(root, Enum.join(path, @joiner))
  def consul(root, path) when is_binary(path) do
    path = [root, path]
           |> Enum.join(@joiner)
           |> String.trim_trailing(@joiner)
    size = String.length(path)
    case Consul.Kv.keys!(path) do
      %HTTPoison.Response{body: keys} when is_list(keys) ->
        keys
        |> Enum.map(fn
          <<_ :: binary-size(size), @joiner :: binary, key :: binary>> -> key
        end)
        |> Enum.filter(& &1 != "")
        |> Enum.map(fn key ->
                      case Peluquero.Utils.consul_key_type(key) do
                        {:nested, _, _} -> nil
                        {:plain, :bag, rest} ->
                          {String.to_atom(rest), consul(path, key)}
                        {:plain, :item, _} ->
                          with %HTTPoison.Response{body: [%{"Value" => value}]} <- Consul.Kv.fetch!("#{path}#{@joiner}#{key}"),
                            do: {String.to_atom(key), value}
                      end
        end)
        |> Enum.filter(& not is_nil(&1))
        |> Enum.into([])
      _ -> []
    end
  end

  ##############################################################################

  defp connection_params(consul) do
    rabbit = consul(consul, ~w|rabbit|)
    [
      host: rabbit[:host],
      port: String.to_integer(rabbit[:port]),
      virtual_host: rabbit[:virtual_host],
      username: rabbit[:user],
      password: rabbit[:password]
    ]
  end
  defp connection_details(consul, type) do
    consul(consul, Atom.to_string(type))
  end
end
