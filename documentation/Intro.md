## Peluquero in a Nutshell

![Peluquero in a Nutshell](https://github.com/am-kantox/peluquero/blob/master/documentation/peluquero.png?raw=true)

## Intro

**Peluquero** _sp._, [peluˈkeɾo] — the hairstylist. This package got this name
after what it basically does is shaving off and styling things.

`Peluquero` is reading all the configured source exchanges, passes each payload
to the chain of configured transformers and publishes the result to
all the configured destination exchanges.

The transformer might be either a function of arity `1`, or a tuple of two
atoms, specifying the module and the function of arity `1` within this module.
Return value of transformed is used as a new `payload`, unless transformer returns
either `:ok` or `nil`. If this is a case, the `payload` is left intact.

`Peluquero` is able to read all the configuration values either from
[`consul`](https://www.consul.io/) or from `config`. Consul takes a precedence
when both are specified for the rabbit config.

## Getting Started

### See [`Getting Started`](gettingstarted.html).

## Configuration

### Configuration (`config.exs`)

```elixir
config :peluquero, :peluquerias,
  local: [
    scissors: [{IO, :inspect}], # functions to apply on input
    rabbits: 2,                 # amount of rabbit consumers
    rabbit: [                   # rabbit configuration
      host: "localhost",
      password: "guest",
      port: 5672,
      username: "guest",
      virtual_host: "/",
      x_message_ttl: "4000"
    ],
    opts: [                     # might be overwritten by consul
      sources: [                # source to subscribe to
        fanout: [
          prefetch_count: 30,
          queue: "fanout.queue1"
        ],
        direct: [
          prefetch_count: 30,
          queue: "direct.queue2",
          routing_key: "direct-routing-key",
          x_max_length: 10_000
        ]
      ],
      destinations: [           # where to post processed messages
        loop: [
          queue: "direct.queue3",
        ]
      ]
    ]
  ],
  remote: [                     # config will be read from consul
    scissors: [{MyApp.Bucket, :put}],
    consul: "configuration/my_app/peluquero/rabbits"
  ]
]
```

### Configuration (`consul`)

```
configuration/my_app/peluquero/rabbits
  destinations/
    exchangeY/
      routing_key    ⇒ transformed
    exchangeZ/
  rabbit/
    host             ⇒ 10.0.0.0
    user             ⇒ my_rabbit_user
    password         ⇒ my_rabbit_password
    port             ⇒ 5672
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

### Configuration example

```elixir
Peluquero.Peluqueria.scissors!(:p1, &IO.puts/1) # adds another handler in runtime
Peluquero.Peluqueria.scissors!(:p2, fn payload ->
  payload
  |> JSON.decode!
  |> Map.put(:timestamp, DateTime.utc_now())
  |> JSON.encode! # if this transformer is last, it’s safe to return a term
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

### Simplified settings with explicit `rabbit` config key

Starting with `0.4.0` we allow [though not recommend] an explicit settings
of `RabbitMQ` parameters directly in `confix.exs` file. See [`Usage`](#usage) section
below for details.

## Installation

```elixir
def deps do
  [
    ...
    {:peluquero, "~> 0.10"},
    ...
  ]
end

def applications do
  [
    ...
    :peluquero,
    ...
  ]

end
```

## Different modes

The easiest way is to start the application as a dependency as shown above.
The drawback, though, might be that the first messages remain unacked, if
some functionality from `MyApp` is required (`MyApp` is not still loaded at
this very moment.)

In that case, one might add `peluquero` in `included_applications` list instead,
and start it manually. The `Supervisor` to be put into the `MyApp`’s supervision
tree is named `Peluquera` (note trailing **“a”**!)

## Usage

`Peluquero` supports running for many different sources/environments (like if we were
allowed to run many instances of the same application.) When multiple environments
are used, they should be referred by name (see `configuration`.)

**config.exs**
```elixir
config :peluquero, :peluquerias, [
  p1:  [scissors: [{IO, :inspect}], consul: "configuration/rabbit1"],
  p2:  [scissors: [fn msg -> msg end],
        rabbit: [
          host: "localhost",
          password: "guest",
          port: 5672,
          username: "guest",
          virtual_host: "/",
          x_message_ttl: "4000"]]
]

# optional
config :peluquero, :peinados, [
  # params are under "configurarion/macroservices/peluquero/redis" key, see above
  redis: [consul: "configuration/macroservices/peluquero"]
]

```

For the single rabbit one might use the simplified syntax:

```elixir
config :peluquero, :consul, "configuration/rabbit1"
config :peluquero, :scissors, [{IO, :inspect}]
```

## Processes

![:observer.start](/documentation/observer.png?raw=true)

## Changelog

### `0.10.0`

* extensive testing,
* code formatted by Elixir formatter,
* `comb!/{2,4}` function to publish to destination queues _without_ shaving,
* `shear!/{2,4}` to publish to destination queues _with_ shaving applied,
* `publish!/{2,4}` to publish to destination queues bypassing actors pool
  (dangerous, not recommended.)

### `0.7.2`

More sophisticated queue name, including all nodes name’s hash.

### `0.7.0`

`Peinados` were granted with diagnostics:

```elixir
@spec children([:full|:short|:uniq]) :: List.t
@spec child?(String.t) :: bool
@spec active?() :: bool
```

Also, new configuration parameter added: `safe_peinados`. When `true`, returns `nil` instead of throwing an exception on calls to incorrect peinados.

### `0.6.0`

- **BREAKING** removed a deprecated `Supervisor.Spec` and dropped support for Elixir < 1.5
- cleanups, readmes, docs

### `0.5.0`

- transparent Redis support (no boilerplate, auto reconnects):

```elixir
defmodule RedisAgent do
  use GenServer
  @peinado :redis

  def start_link(_opts) do
    GenServer.start_link(fn -> %{} end, name: __MODULE__)
  end

  def get(key), do: Peluquero.Peinados.get(@peinado, key)
  def put(key, value), do: Peluquero.Peinados.set(@peinado, key, value)
end
```

### `0.4.0`

- allow explicit `RabbitMQ` settings in config (no consul needed.)

---

Documentation can be found at [https://hexdocs.pm/peluquero](https://hexdocs.pm/peluquero).
