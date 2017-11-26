defmodule Peluquero.Redis do
  @moduledoc false

  use GenServer

  use Peluquero.Namer
  require Logger

  ##############################################################################
  # https://github.com/artemeff/exredis
  ##############################################################################

  def get(name, key), do: GenServer.call(fqname(name), {:get, key})
  def set(name, key, value), do: GenServer.cast(fqname(name), {:set, key, value})
  def del(name, key), do: GenServer.cast(fqname(name), {:del, key})

  ##############################################################################

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: fqname(opts))

  def init(opts), do: {:ok, [name: opts[:name], redis: redis_connect(opts[:name], opts[:consul])]}

  def shutdown, do: GenServer.cast(__MODULE__, :shutdown)

  def handle_info({:DOWN, _, :process, _pid, reason}, state) do
    Logger.log(:info, "⇑ reconnecting after ⇓ for #{inspect(reason)} reason")
    {:noreply, Keyword.merge(state, redis: redis_connect(state[:name], state[:consul]))}
  end

  def handle_cast(:shutdown, state) do
    Logger.log(:info, "⇓ shutdown options: #{inspect(state[:opts])}")
    Exredis.stop(state[:redis])
    {:noreply, nil}
  end

  def handle_cast({:set, key, value}, state) do
    Exredis.query(state[:redis], ["SET", key, value])
    {:noreply, state}
  end

  def handle_cast({:del, key}, state) do
    Exredis.query(state[:redis], ["DEL", key])
    {:noreply, state}
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, Exredis.query(state[:redis], ["GET", key]), state}
  end

  ##############################################################################

  defp redis_connect(name, consul) do
    conn_params = connection_params(consul, name)

    case Exredis.start_link(conn_params) do
      {:ok, client} ->
        Logger.log(
          :warn,
          ~s|★ Redis: [name: :#{name}, consul: "#{consul}", redis: #{inspect(client)}]|
        )

        client

      {:error, reason} ->
        # Reconnection loop
        Logger.log(:warn, "⇓ redis™ error, reason: #{inspect(reason)}")
        Process.sleep(1_000)
        redis_connect(name, consul)
    end
  end

  ##############################################################################

  defp connection_params(consul, name) do
    with redis <- Peluquero.Utils.consul(consul, name) do
      %Exredis.Config.Config{
        host: redis[:host],
        port: String.to_integer(redis[:port]),
        db: String.to_integer(redis[:database]),
        # redis.pwd,
        password: "",
        reconnect: :no_reconnect,
        max_queue: :infinity,
        behaviour: :drop
      }
    end
  end
end
