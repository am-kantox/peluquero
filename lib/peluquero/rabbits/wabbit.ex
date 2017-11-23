defmodule Peluquero.Rabbit.Wabbit do
  defmodule Connection do
    @behaviour Peluquero.Rabbit.Connection

    defdelegate open(name), to: Wabbit.Connection, as: :start_link
  end

  defmodule Channel do
    @behaviour Peluquero.Rabbit.Channel

    defdelegate open(conn), to: Wabbit.Connection, as: :open_channel
    defdelegate close(conn), to: Wabbit.Connection, as: :close
  end

  defmodule Basic do
    @behaviour Peluquero.Rabbit.Basic

    defdelegate ack(channel, delivery_tag), to: Wabbit.Basic
    defdelegate ack(channel, delivery_tag, opts), to: Wabbit.Basic
    defdelegate consume(channel, queue), to: Wabbit.Basic
    defdelegate consume(channel, queue, consumer_pid), to: Wabbit.Basic
    defdelegate publish(channel, payload), to: Wabbit.Basic
    defdelegate publish(channel, payload, options), to: Wabbit.Basic
    defdelegate qos(channel), to: Wabbit.Basic
    defdelegate qos(channel, opts), to: Wabbit.Basic
    defdelegate reject(channel, delivery_tag), to: Wabbit.Basic
    defdelegate reject(channel, delivery_tag, opts), to: Wabbit.Basic
  end

  defmodule Exchange do
    @behaviour Peluquero.Rabbit.Exchange

    defdelegate declare(channel, exchange), to: Wabbit.Exchange
    defdelegate declare(channel, exchange, type), to: Wabbit.Exchange
    defdelegate declare(channel, exchange, type, opts), to: Wabbit.Exchange
  end

  defmodule Queue do
    @behaviour Peluquero.Rabbit.Queue

    defdelegate declare(channel), to: Wabbit.Queue
    defdelegate declare(channel, queue), to: Wabbit.Queue
    defdelegate declare(channel, queue, opts), to: Wabbit.Queue
    defdelegate bind(channel, queue, exchange), to: Wabbit.Queue
    defdelegate bind(channel, queue, exchange, opts), to: Wabbit.Queue
    defdelegate unbind(channel, queue, exchange), to: Wabbit.Queue
    defdelegate unbind(channel, queue, exchange, opts), to: Wabbit.Queue
    defdelegate delete(channel, queue), to: Wabbit.Queue
    defdelegate delete(channel, queue, opts), to: Wabbit.Queue
  end

  defmacro __using__(_opts \\ []) do
    quote do
      alias Peluquero.Rabbit.Wabbit.{Connection,Channel,Basic,Exchange,Queue}
    end
  end
end
