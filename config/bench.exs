use Mix.Config

config :logger, level: :debug

config :peluquero, :peluquerias,
  test_peluquero: [
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
      sources: [],
      destinations: [
        test_peluquero_out: [
          queue: "direct.shaved-queue"
        ]
      ]
    ]
  ]

config :peluquero, :peinados, []
#   eventory: [consul: "configuration/macroservices_dev/redis"]
# ]

config :peluquero, :pool, actors: [size: 8, max_overflow: 100]
