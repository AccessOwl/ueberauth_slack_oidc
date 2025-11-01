defmodule Ueberauth.Strategy.SlackOIDCTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  @router SpecRouter.init([])

  doctest Ueberauth.Strategy.SlackOIDC

  setup do
    ExVCR.Config.cassette_library_dir(
      "test/support/fixtures/vcr_cassettes",
      "test/support/fixtures/custom_cassettes"
    )

    :ok
  end

  test "simple request phase" do
    {:ok, response_basic} =
      "test/support/fixtures/slack_oidc_response_basic.html"
      |> Path.expand()
      |> File.read()

    conn =
      :get
      |> conn("/auth/slack")
      |> SpecRouter.call(@router)

    assert conn.resp_body == String.trim(response_basic)
  end

  test "advanced request phase" do
    {:ok, response_advanced} =
      "test/support/fixtures/slack_oidc_response_advanced.html"
      |> Path.expand()
      |> File.read()

    conn =
      :get
      |> conn(
        "/auth/slack?scope=users:read&user_scope=dnd:write" <>
          "&state=obscure_custom_value&unknown_param=should_be_ignored"
      )
      |> SpecRouter.call(@router)

    assert conn.resp_body == String.trim(response_advanced)
  end

  test "default callback phase" do
    query = %{code: "code_abc"} |> URI.encode_query()

    use_cassette "slack-oidc-responses", custom: true do
      conn =
        :get
        |> conn("/auth/slack/callback?#{query}")
        |> SpecRouter.call(@router)

      assert conn.resp_body == "slack callback"

      auth = conn.assigns.ueberauth_auth

      assert auth.provider == :slack
      assert auth.strategy == Ueberauth.Strategy.SlackOIDC
    end
  end
end
