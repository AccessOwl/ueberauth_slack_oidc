defmodule Ueberauth.Strategy.SlackOIDC do
  @moduledoc """
  Implements an ÜeberauthSlack strategy for authentication with Slack OpenID Connect API.

  When configuring the strategy in the Üeberauth providers, you can specify some defaults.

  * `uid_field` - The field to use as the UID field. This can be any populated field in the info struct. Default `:email`
  * `scope` - The scope to request by default from slack (permissions). Default "openid"
  * `oauth2_module` - The OAuth2 module to use. Default Ueberauth.Strategy.SlackOIDC.OAuth

  ```elixir

  config :ueberauth, Ueberauth,
    providers: [
      slack: { Ueberauth.Strategy.SlackOIDC, [uid_field: :nickname, scope: "openid,email,profile"] }
    ]
  ```
  """
  use Ueberauth.Strategy,
    uid_field: :email,
    scope: "openid",
    oauth2_module: Ueberauth.Strategy.SlackOIDC.OAuth

  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra

  # When handling the request just redirect to Slack
  @doc false
  def handle_request!(conn) do
    scopes = conn.params["scope"] || option(conn, :scope)
    opts = [scope: scopes]

    opts =
      if conn.params["state"] do
        Keyword.put(opts, :state, conn.params["state"])
      else
        with_state_param(opts, conn)
      end

    team = option(conn, :team)
    opts = if team, do: Keyword.put(opts, :team, team), else: opts

    callback_url = callback_url(conn)

    callback_url =
      if String.ends_with?(callback_url, "?"),
        do: String.slice(callback_url, 0..-2//-1),
        else: callback_url

    opts = Keyword.put(opts, :redirect_uri, callback_url)
    module = option(conn, :oauth2_module)

    redirect!(conn, apply(module, :authorize_url!, [opts]))
  end

  # When handling the callback, if there was no errors we need to
  # make two calls. The first, to fetch the slack auth is so that we can get hold of
  # the user id so we can make a query to fetch the user info.
  # So that it is available later to build the auth struct, we put it in the private section of the conn.
  @doc false
  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    module = option(conn, :oauth2_module)
    params = [code: code]
    redirect_uri = get_redirect_uri(conn)

    options = %{
      options: [
        client_options: [redirect_uri: redirect_uri]
      ]
    }

    case apply(module, :get_token!, [params, options]) do
      %{access_token: nil} = token_struct ->
        set_errors!(conn, [
          error(
            token_struct.other_params["error"],
            token_struct.other_params["error_description"]
          )
        ])

      %{access_token: _} = token_struct ->
        conn
        |> store_token(token_struct)
        |> fetch_auth(token_struct)
    end
  end

  # If we don't match code, then we have an issue
  @doc false
  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  # We store the token for use later when fetching the slack auth and user and constructing the auth struct.
  @doc false
  defp store_token(conn, token) do
    put_private(conn, :slack_token, token)
  end

  # Remove the temporary storage in the conn for our data. Run after the auth struct has been built.
  @doc false
  def handle_cleanup!(conn) do
    conn
    |> put_private(:slack_auth, nil)
    |> put_private(:slack_identity, nil)
    |> put_private(:slack_user, nil)
    |> put_private(:slack_token, nil)
    |> put_private(:slack_bot_token, nil)
  end

  # The structure of the requests is such that it is difficult to provide cusomization for the uid field.
  # instead, we allow selecting any field from the info struct
  @doc false
  def uid(conn) do
    Map.get(info(conn), option(conn, :uid_field))
  end

  @doc false
  def credentials(conn) do
    token = conn.private.slack_token
    auth = conn.private[:slack_auth]
    scope_string = token.other_params["scope"] || ""
    scopes = String.split(scope_string, ",")

    %Credentials{
      token: token.access_token,
      refresh_token: token.refresh_token,
      expires_at: token.expires_at,
      token_type: token.token_type,
      expires: !!token.expires_at,
      scopes: scopes,
      other: %{
        user: get_in(auth, ["user"]),
        user_id: Map.get(auth, "sub"),
        team: Map.get(auth, "https://slack.com/team_name"),
        team_id: Map.get(auth, "https://slack.com/team_id"),
        team_domain: Map.get(auth, "https://slack.com/team_domain")
      }
    }
  end

  @doc false
  def info(conn) do
    auth = conn.private[:slack_auth]

    image_urls =
      auth
      |> Map.keys()
      |> Enum.filter(&(&1 =~ ~r/^https:\/\/slack.com\/user_image/))
      |> Enum.into(%{}, &{&1, auth[&1]})

    team_image_urls =
      auth
      |> Map.keys()
      |> Enum.filter(&(&1 =~ ~r/^https:\/\/slack.com\/team_image/))
      |> Enum.into(%{}, &{&1, auth[&1]})

    %Info{
      name: Map.get(auth, "name"),
      first_name: Map.get(auth, "given_name"),
      last_name: Map.get(auth, "family_name"),
      email: Map.get(auth, "email"),
      image: Map.get(auth, "picture"),
      urls: Map.merge(image_urls, team_image_urls)
    }
  end

  @doc false
  def extra(conn) do
    %Extra{
      raw_info: %{
        auth: conn.private[:slack_auth],
        identity: conn.private[:slack_identity],
        token: conn.private[:slack_token],
        bot_token: conn.private[:slack_bot_token],
        user: conn.private[:slack_user],
        team: conn.private[:slack_team]
      }
    }
  end

  # Before we can fetch the user, we first need to fetch the auth to find out what the user id is.
  defp fetch_auth(conn, token) do
    case Ueberauth.Strategy.SlackOIDC.OAuth.get(token, "/openid.connect.userInfo") do
      {:ok, %OAuth2.Response{status_code: 401, body: _body}} ->
        set_errors!(conn, [error("token", "unauthorized")])

      {:ok, %OAuth2.Response{status_code: status_code, body: auth}}
      when status_code in 200..399 ->
        cond do
          auth["ok"] ->
            put_private(conn, :slack_auth, auth)

          true ->
            set_errors!(conn, [error(auth["error"], auth["error"])])
        end

      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end

  defp get_redirect_uri(%Plug.Conn{} = conn) do
    config = Application.get_env(:ueberauth, Ueberauth)
    redirect_uri = Keyword.get(config, :redirect_uri)

    if is_nil(redirect_uri) do
      callback_url(conn)
    else
      redirect_uri
    end
  end
end
