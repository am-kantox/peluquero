use Mix.Config

config :peluquero, :peluquerias, [
  p1:  [scissors: [],
        rabbits: 1,
        consul: "configuration/macroservices/peluquero",
        pool: [actors: [size: 50, max_overflow: 100]]],
  p2:  [scissors: [],
        rabbits: 1,
        rabbit: [
          host: "localhost",
          password: "guest",
          port: 5672,
          username: "guest",
          virtual_host: "/",
          x_message_ttl: "4000"]]
]

config :peluquero, :peinados, [
  eventory: [consul: "configuration/erniecluster/redis"]
]
