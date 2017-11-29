use Mix.Config

config :logger, level: :debug

config :peluquero, :peluquerias,
  hairy: [
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
        loop: [
          queue: "direct.shaved-queue",
        ]
      ]
    ]
  ],
  shaved: [
    scissors: [{Peluquero.Test.Bucket, :put}],
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
        loop: [
          prefetch_count: 10,
          queue: "direct.shaved-queue",
        ]
      #],
      #destinations: [
      #  fanout: [
      #    queue: "fanout.collect-queue",
      #  ]
      ]
    ]
  ]

# With mix test --include local_only
# change the value in the line below to:
#   [eventory: [consul: "configuration/erniecluster/redis"]]
# config :peluquero, :safe_peinados, true
config :peluquero, :peinados, []
