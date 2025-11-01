import Config

config :ueberauth, Ueberauth,
  json_library: Jason,
  providers: [
    slack:
      {Ueberauth.Strategy.SlackOIDC,
       [
         scope: "openid"
       ]}
  ]

config :oauth2, adapter: Tesla.Adapter.Hackney

config :ueberauth, Ueberauth.Strategy.SlackOIDC.OAuth,
  client_id: "clientidsomethingrandom",
  client_secret: "clientsecret-somethingsecret"

config :plug, :validate_header_keys_during_test, true
