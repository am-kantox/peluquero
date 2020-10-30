use Mix.Config

config :logger, level: :info

config :peluquero, :peluquerias,
  hairy: [
    scissors: [{IO, :inspect}],
    rabbits: 2,
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
          queue: "fanout.test-queue"
        ],
        direct: [
          prefetch_count: 30,
          queue: "direct.test-queue",
          routing_key: "direct-routing-key",
          x_max_length: 10_000
        ]
      ],
      destinations: [
        # loop: [
        #   queue: "direct.shaved-queue",
        #   x_max_length: 10_000,
        #   durable: false
        # ]
      ]
    ]
  ],
  shaved: [
    scissors: [],
    rabbits: 2,
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
        #  loop: [
        #    prefetch_count: 10,
        #    queue: "direct.shaved-queue"
        #    x_max_length: 10_000,
        #    durable: false
        #  ]
        shaved: [
          queue: "direct.shaved-queue",
          routing_key: "direct-routing-key",
          durable: false
        ]
      ],
      destinations: [
        copy_shaved: [
          queue: "direct.collect-queue",
          routing_key: "direct-routing-key",
          x_max_length: 10_000
        ]
      ]
    ]
  ]

config :peluquero, :peinados,
  no1: [
    redis: [database: "0", host: "127.0.0.1", port: "6379"]
  ]

config :peluquero, :pool, actors: [size: 100, max_overflow: 200]
