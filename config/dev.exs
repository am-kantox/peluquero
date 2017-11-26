use Mix.Config

# p1:  [scissors: [],
#       rabbits: 1,
#       consul: "configuration/macroservices_dev/peluquero",
#       pool: [actors: [size: 50, max_overflow: 100]]],
config :peluquero, :peluquerias,
  p2: [
    scissors: [],
    rabbits: 2,
    rabbit: [
      host: "localhost",
      password: "guest",
      port: 5672,
      username: "guest",
      virtual_host: "/",
      x_message_ttl: "4000"
    ]
  ],
  p3: [
    scissors: [],
    rabbits: 5,
    rabbit: [
      host: "localhost",
      password: "guest",
      port: 5672,
      username: "guest",
      virtual_host: "/",
      x_message_ttl: "4000"
    ]
  ]

config :peluquero, :peinados, []
#   eventory: [consul: "configuration/macroservices_dev/redis"]
# ]

config :peluquero, :pool, actors: [size: 8, max_overflow: 100]
