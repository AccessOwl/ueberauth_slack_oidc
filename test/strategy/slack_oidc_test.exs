defmodule Ueberauth.Strategy.SlackOIDCTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  alias Ueberauth.Strategy.Helpers

  @router SpecRouter.init([])

  doctest Ueberauth.Strategy.SlackOIDC

  setup do
    ExVCR.Config.cassette_library_dir(
      "test/support/fixtures/vcr_cassettes",
      "test/support/fixtures/custom_cassettes"
    )

    # Create a connection with Ueberauth's CSRF cookies so they can be recycled during tests
    routes = Ueberauth.init([])

    csrf_conn = conn(:get, "/auth/slack", %{}) |> Ueberauth.call(routes)
    csrf_state = Helpers.with_state_param([], csrf_conn) |> Keyword.get(:state)
    {:ok, csrf_conn: csrf_conn, csrf_state: csrf_state}
  end

  test "simple request phase" do
    conn =
      :get
      |> conn("/auth/slack")
      |> SpecRouter.call(@router)

    state = conn.private.ueberauth_state_param

    response_basic = """
    <html><body>You are being <a href="https://slack.com/openid/connect/authorize?client_id=clientidsomethingrandom&amp;redirect_uri=http%3A%2F%2Fwww.example.com%2Fauth%2Fslack%2Fcallback&amp;response_type=code&amp;scope=openid&amp;state=#{state}">redirected</a>.</body></html>
    """

    assert conn.resp_body == String.trim(response_basic)
  end

  test "advanced request phase" do
    response_advanced = """
    <html><body>You are being <a href="https://slack.com/openid/connect/authorize?client_id=clientidsomethingrandom&amp;redirect_uri=http%3A%2F%2Fwww.example.com%2Fauth%2Fslack%2Fcallback&amp;response_type=code&amp;scope=openid%2Cemail&amp;state=obscure_custom_value">redirected</a>.</body></html>
    """

    conn =
      :get
      |> conn(
        "/auth/slack?scope=openid,email" <>
          "&state=obscure_custom_value&unknown_param=should_be_ignored"
      )
      |> SpecRouter.call(@router)

    assert conn.resp_body == String.trim(response_advanced)
  end

  test "default callback phase fails without right state" do
    query = %{code: "code_abc"} |> URI.encode_query()

    use_cassette "slack-oidc-responses", custom: true do
      conn =
        :get
        |> conn("/auth/slack/callback?#{query}")
        |> SpecRouter.call(@router)

      assert conn.resp_body == "slack callback"

      refute Map.has_key?(conn.assigns, :ueberauth_auth)

      assert conn.assigns.ueberauth_failure == %Ueberauth.Failure{
               strategy: Ueberauth.Strategy.SlackOIDC,
               errors: [
                 %Ueberauth.Failure.Error{
                   message_key: "csrf_attack",
                   message: "Cross-Site Request Forgery attack"
                 }
               ],
               provider: :slack
             }
    end
  end

  test "default callback phase works with right state", %{
    csrf_state: csrf_state,
    csrf_conn: csrf_conn
  } do
    use_cassette "slack-oidc-responses", custom: true do
      conn =
        :get
        |> conn("/auth/slack/callback", %{code: "code_abc", state: csrf_state})
        |> set_csrf_cookies(csrf_conn)
        |> SpecRouter.call(@router)

      assert conn.resp_body == "slack callback"

      auth = conn.assigns.ueberauth_auth

      assert auth.provider == :slack
      assert auth.strategy == Ueberauth.Strategy.SlackOIDC
    end
  end

  defp set_csrf_cookies(conn, csrf_conn) do
    conn
    |> init_test_session(%{})
    |> recycle_cookies(csrf_conn)
    |> fetch_cookies()
  end
end
