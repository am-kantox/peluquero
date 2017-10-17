use Mix.Config

config :peluquero, :peluquerias, [
  local: [scissors: [],
          rabbits: 1,
          rabbit: [
            host: "localhost",
            password: "guest",
            port: 5672,
            username: "guest",
            virtual_host: "/",
            x_message_ttl: "4000"]]
]

config :peluquero, :peinados, []
