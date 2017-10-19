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

# With mix test --include local_only
# change the value in the line below to:
#   [eventory: [consul: "configuration/erniecluster/redis"]]
# config :peluquero, :safe_peinados, true
config :peluquero, :peinados, []
