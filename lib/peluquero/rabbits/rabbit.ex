defmodule Peluquero.Rabbit.Connection do
  @moduledoc """
  The default `Connection` behaviour for all the rabbits.
  """

  defstruct [:pid]

  @type t :: %Peluquero.Rabbit.Connection{pid: pid}

  @doc "Opens an new Connection to an AMQP broker."
  @callback open(keyword | String.t) :: {:ok, t} | {:error, atom} | {:error, any}
end

defmodule Peluquero.Rabbit.Channel do
  @moduledoc """
  The default `Channel` behaviour for all the rabbits.
  """

  defstruct [:conn, :pid]

  @type t :: %Peluquero.Rabbit.Channel{conn: Peluquero.Rabbit.Connection.t, pid: pid}

  @doc "Opens a new Channel in a previously opened Connection."
  @callback open(Peluquero.Rabbit.Connection.t) :: {:ok, Peluquero.Rabbit.Channel.t} | any

  @doc "Closes an open Channel."
  @callback close(Peluquero.Rabbit.Channel.t) :: :ok | :closing
end

defmodule Peluquero.Rabbit.Basic do
  @moduledoc """
  The default `Basic` behaviour for all the rabbits.
  """

  @doc "Acknowledges one or more messages."
  @callback ack(Peluquero.Rabbit.Channel.t, String.t, keyword) ::
            :ok |
            :blocked |
            :closing

  @doc "Registers a queue consumer process."
  @callback consume(Peluquero.Rabbit.Channel.t, String.t, pid | nil, keyword) :: {:ok, String.t}

  @doc "Publishes a message to an Exchange."
  @callback publish(Peluquero.Rabbit.Channel.t, String.t, String.t, String.t, keyword) ::
            :ok |
            :blocked |
            :closing

  @doc "Sets the message prefetch count or prefetech size (in bytes)."
  @callback qos(Peluquero.Rabbit.Channel.t, keyword) :: :ok

  @doc "Rejects (and, optionally, requeues) a message."
  @callback reject(Peluquero.Rabbit.Channel.t, String.t, keyword) ::
            :ok |
            :blocked |
            :closing
end

defmodule Peluquero.Rabbit.Exchange do
  @moduledoc """
  The default `Exchange` behaviour for all the rabbits.
  """

  @doc "Declares an Exchange."
  @callback declare(Peluquero.Rabbit.Channel.t, String.t, atom, keyword) :: :ok
end

defmodule Peluquero.Rabbit.Queue do
  @moduledoc """
  The default `Queue` behaviour for all the rabbits.
  """

  @doc "Declares a queue. The optional `queue` parameter is used to set the name."
  @callback declare(Peluquero.Rabbit.Channel.t, String.t, keyword) :: {:ok, map}

  @doc "Binds a Queue to an Exchange"
  @callback bind(Peluquero.Rabbit.Channel.t, String.t, String.t, keyword) :: :ok

  @doc "Unbinds a Queue from an Exchange"
  @callback unbind(Peluquero.Rabbit.Channel.t, String.t, String.t, keyword) :: :ok

  @doc "Deletes a Queue by name"
  @callback delete(Peluquero.Rabbit.Channel.t, String.t, keyword) :: {:ok, map}
end
