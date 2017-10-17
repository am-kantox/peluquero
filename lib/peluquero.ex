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
  use Peluquero.Namer

  require Logger

  @doc false
  def start(_type, args) do
    import Supervisor.Spec, warn: false

    peluquerias = Application.get_env(:peluquero, :peluquerias, [])
    peinados = Application.get_env(:peluquero, :peinados, [])

    Logger.warn(fn -> "✂ Peluquero started:\n  — peluquerias: #{inspect peluquerias}.\n  — peinados: #{inspect peinados}.\n  — args: #{inspect args}.\n" end)

    amqps = case Enum.map(peluquerias, fn {name, settings} ->
              supervisor(Peluquero.Peluqueria,
                          [Keyword.merge(settings, name: name)],
                          id: fqname(Peluquero.Peluqueria, name))
            end) do
              [] -> [supervisor(Peluquero.Peluqueria, [])]
              many -> many
            end

    redises = supervisor(Peluquero.Peinados, [peinados],
                          id: fqname(Peluquero.Peinados, "Procurator"))

    opts = [strategy: :one_for_one, name: fqname(Peluquero.Supervisor, args)]
    Supervisor.start_link([redises | amqps], opts)
  end

end
