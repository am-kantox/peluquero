defmodule Peluquero do
  @moduledoc """
  Application handler for the `Peluquero` application.

  `Peluquero` is the multi-purpose, multi-protocol message handling utility.
  It provides the transparent way to subscribe to rabbit queues, re-shape the
  messages and spit out everything to other queues. It also supports transparent
  redis connection for those who need to store the data in redis.

  Basically, one would configure `Peluquero` through [`consul`](https://consul.io/)
  (explicit configuration is also allowed, though I would strongly encourage users
  to use `consul` for the configuration,) and declare so-called `scissors` to
  mutate the messages from sources before putting them into destinations.

  Multiple sources as well as multiple destinations are allowed. Example of the
  configuration that reads two different message queues, transforms data and
  spits it out to the “common” queue, that might be used by subscribers (join
  different sources):

  ```elixir
  config :peluquero, :peluquerias, [
    football_scores:  [
      scissors: [{MyModule, :my_function}],
      consul: "configuration/football",
      pool: [actors: [size: 50, max_overflow: 100]]]]
  ```

  The configuration above would read the settings for rabbits from consul (under
  `football` key,) subscribe to the rabbit using the pool of `50` workers and
  call `MyModule.my_function/1` on each subsequent message received from sources.

  As `MyModule.my_function/1` returns, the value it returned will be placed into
  all the destination queues, specified in `consul` (if it returns `nil`, the
  original value will be used.) The tree structure of `consul`
  settings would be as follows:

  ```
  configuration/football/
    destinations/
      exchangeY/
        routing_key    ⇒ transformed
      exchangeZ/
    rabbit/
      host             ⇒ localhost
      password         ⇒ my_rabbit_password
      port             ⇒ 5672
      user             ⇒ my_rabbit_user
      virtual_host     ⇒ my_virtual_host
      x_message_ttl    ⇒ 4000
    sources/
      exchangeA/
        prefetch_count ⇒ 30
        routing_key    ⇒ to_transform
      exchangeB/
        prefetch_count ⇒ 50
        queue          ⇒ queue_name
        routing_key    ⇒ to_transform
    redis/
      host             ⇒ localhost
      port             ⇒ 11887
      database         ⇒ 0
      pwd              ⇒ my_redis_password
  ```
  **my_module_1.ex**
  ```elixir
  Peluquero.Peluqueria.scissors!(:p1, &IO.puts/1) # adds another handler in runtime
  Peluquero.Peluqueria.scissors!(:p2, fn payload ->
    payload
    |> Jason.decode!
    |> Map.put(:timestamp, DateTime.utc_now())
    |> Jason.encode! # if this transformer is last, it’s safe to return a term
  end) # adds another handler in runtime, to :p2 named instance
  ```

  The result of the above would be:

  * direct exchanges `exchangeA` and `exchangeB` would be consumed with
    `routing_key` being `to_transform`;
  * all the messages will be put to `stdout` _twice_ (one with `IO.inspect`,
    configured in `config.exs` and another with `IO.puts`, attached in runtime);
  * all the messages will be extended with new `:timestamp` field;
  * all the messages will be published to direct `exchangeY` with `routing_key`
    being set to `transformed` and to fanout exchange `exchangeZ`.

  Handlers might be added in runtime using `Peluquero.handler!/1`, that accepts
  any type of transformers described above. Handlers are _appended_ to the list.
  Maybe later this function would accept an optional parameter, saying whether
  the handler should be _appended_, or _prepended_.

  Also, `Peluquero` simplifies the `Redis` access: all the connection boilerplate
  is handler by `Peluquero`, allowing storing a `Redis` values based on streaming
  queue (e.g. “current value”) as easy as declaring one `scissors` delegating to
  `Peluquero.Peinados.set/3`.
  """

  use Application

  @doc false
  @spec start(:permanent | :transient | :temporary, start_args :: term) ::
          {:ok, pid}
          | {:ok, pid, term}
          | {:error, reason :: term}
  def start(_type, args) do
    # Supervisor.start_link(
    #   Peluquera,
    #   args,
    #   strategy: :one_for_one, name: __MODULE__
    # )
    Peluquera.start_link(args)
  end
end
