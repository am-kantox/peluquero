## Getting Started

### Why?

One uses `Peluquero` to put the whole interoperation with [`RabbitMQ`](https://rabbitmq.com/) under the hood.
It effectively establishes, keeps and watches the connections, allows very detail
configuration tuning and provides the extensive flexibility and reliability while
dealing with [`RabbitMQ`](https://rabbitmq.com/).

### Simplest config

Imagine one wants to read two different queues, `"fanout.queue"` that is bound to `fanout`
exchange, and `"direct.queue"` bound to `direct` exchange. The messages read should be mixed
together, _coerced_ to the same representation, _formatted_ and then published to another
queue `"shaved.queue"` with a routing key `"shaved-routing-key"`.

The config below should be self-explanatory.

```elixir
config :peluquero, :peluquerias,
  rabbit1: [
    scissors: [{MyModule, :coerce}, {MyOtherModule, :format}],
    rabbits: 5,
    rabbit: [
      host: "localhost",
      password: "guest",
      port: 5672,
      username: "guest",
      virtual_host: "/",
      x_message_ttl: "4000"
    ],
    opts: [
      sources: [
        fanout: [
          prefetch_count: 30,
          queue: "fanout.queue"
        ],
        direct: [
          queue: "direct.queue",
          routing_key: "direct-routing-key",
          x_max_length: 10_000
        ]
      ],
      destinations: [
        filtered: [
          queue: "shaved.queue",
          routing_key: "shaved-routing-key"
        ]
      ]
    ]
  ]
]
```

The code needed to accomplish this task: **none**. Config is enough. Yay.

### Sophisticated tuning

`Peluquero` allows to config/tune up nearly everything, through config file.
Also, instead of storing the configuration in the file near the source code,
one might use [`Consul`](https://consul.io/) to store configuration.
See  `Intro` for the config details.

Also, `Peluquero` allows to add/remove scissors (functions used to “shave”
the input to produce the output) on the fly. Scissors are stored as a `FILO`
and called one by one.
