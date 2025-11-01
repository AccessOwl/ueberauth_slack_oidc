defmodule Ueberauth.Strategy.SlackOIDC.OAuthTest do
  use ExUnit.Case, async: true

  import Ueberauth.Strategy.SlackOIDC.OAuth, only: [client: 0]

  setup do
    {:ok, %{client: client()}}
  end

  test "creates correct client", %{client: client} do
    assert client.client_id == "clientidsomethingrandom"
    assert client.client_secret == "clientsecret-somethingsecret"
    assert client.redirect_uri == ""
    assert client.strategy == Ueberauth.Strategy.SlackOIDC.OAuth
    assert client.authorize_url == "https://slack.com/oauth/v2/authorize"
    assert client.token_url == "https://slack.com/api/oauth.v2.access"
    assert client.site == "https://slack.com/api"
  end
end
