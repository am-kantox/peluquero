defmodule Peluquero.Rabbit.Amqp do
  defmodule Connection do
    @behaviour Peluquero.Rabbit.Connection

    defdelegate open(name), to: AMQP.Connection
  end

  defmodule Channel do
    @behaviour Peluquero.Rabbit.Channel

    defdelegate open(conn), to: AMQP.Channel
    defdelegate close(conn), to: AMQP.Channel
  end

  defmodule Basic do
    @behaviour Peluquero.Rabbit.Basic

    defdelegate ack(channel, delivery_tag), to: AMQP.Basic
    defdelegate ack(channel, delivery_tag, opts), to: AMQP.Basic
    defdelegate consume(channel, queue), to: AMQP.Basic
    defdelegate consume(channel, queue, consumer_pid), to: AMQP.Basic
    defdelegate consume(channel, queue, consumer_pid, opts), to: AMQP.Basic
    defdelegate publish(channel, exchange, routing_key, payload), to: AMQP.Basic
    defdelegate publish(channel, exchange, routing_key, payload, opts), to: AMQP.Basic
    defdelegate qos(channel), to: AMQP.Basic
    defdelegate qos(channel, opts), to: AMQP.Basic
    defdelegate reject(channel, delivery_tag), to: AMQP.Basic
    defdelegate reject(channel, delivery_tag, opts), to: AMQP.Basic
  end

  defmodule Exchange do
    @behaviour Peluquero.Rabbit.Exchange

    defdelegate declare(channel, exchange), to: AMQP.Exchange
    defdelegate declare(channel, exchange, type), to: AMQP.Exchange
    defdelegate declare(channel, exchange, type, opts), to: AMQP.Exchange
  end

  defmodule Queue do
    @behaviour Peluquero.Rabbit.Queue

    defdelegate declare(channel), to: AMQP.Queue
    defdelegate declare(channel, queue), to: AMQP.Queue
    defdelegate declare(channel, queue, opts), to: AMQP.Queue
    defdelegate bind(channel, queue, exchange), to: AMQP.Queue
    defdelegate bind(channel, queue, exchange, opts), to: AMQP.Queue
    defdelegate unbind(channel, queue, exchange), to: AMQP.Queue
    defdelegate unbind(channel, queue, exchange, opts), to: AMQP.Queue
    defdelegate delete(channel, queue), to: AMQP.Queue
    defdelegate delete(channel, queue, opts), to: AMQP.Queue
  end

  defmacro __using__(_opts \\ []) do
    quote do
      alias Peluquero.Rabbit.Amqp.{Connection,Channel,Basic,Exchange,Queue}
    end
  end
end
