defmodule Peluquero.Redis do
  @moduledoc false

  use GenServer

  @reconnect_sleep 5

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

  defp redis!(opts) do
    if is_nil(opts[:consul]) do
      redis_connect(:redis, opts[:name], opts[:redis_config])
    else
      redis_connect(:consul, opts[:name], opts[:consul])
    end
  end

  def init(opts) do
    {:ok, [name: opts[:name], redis: redis!(opts)]}
  end

  def shutdown, do: GenServer.cast(__MODULE__, :shutdown)

  def handle_info({:DOWN, _, :process, _pid, reason}, state) do
    Logger.log(:info, "⇑ reconnecting after ⇓ for #{inspect(reason)} reason")
    {:noreply, Keyword.merge(state, redis: redis!(state))}
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

  defp redis_connect(config_from, name, consul_or_params) do
    conn_params = connection_params(config_from, consul_or_params, name)

    case Exredis.start_link(conn_params) do
      {:ok, client} ->
        Logger.log(
          :warn,
          ~s|★ Redis: [name: :#{name}, redis: #{inspect(client)}]|
        )

        client

      {:error, reason} ->
        # Reconnection loop
        Logger.log(:warn, "⇓ redis™ error, reason: #{inspect(reason)}")
        Process.sleep(1_000)
        redis_connect(config_from, name, consul_or_params)
    end
  end

  ##############################################################################

  defp connection_params(:redis, redis, name) do
    %Exredis.Config.Config{
      host: redis[:host],
      port: String.to_integer(redis[:port]),
      db: String.to_integer(redis[:database]),
      password: redis[:password] || "",
      reconnect: @reconnect_sleep,
      max_queue: :infinity,
      behaviour: :drop
    }
  end

  if Code.ensure_compiled?(Consul.Kv) do
    defp connection_params(:consul, consul, name) do
      with redis <- Peluquero.Utils.consul(consul, name) do
        %Exredis.Config.Config{
          host: redis[:host],
          port: String.to_integer(redis[:port]),
          db: String.to_integer(redis[:database]),
          password: redis[:password] || "",
          reconnect: @reconnect_sleep,
          max_queue: :infinity,
          behaviour: :drop
        }
      end
    end
  end
end
