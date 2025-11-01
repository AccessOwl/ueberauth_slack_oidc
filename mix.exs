defmodule UeberauthSlackOIDC.MixProject do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :ueberauth_slack_oidc,
      version: @version,
      name: "Ueberauth Slack OIDC",
      package: package(),
      elixir: "~> 1.8",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/AccessOwl/ueberauth_slack_oidc",
      homepage_url: "https://github.com/AccessOwl/ueberauth_slack_oidc",
      description: "Slack OIDC Überauth strategy",
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :ueberauth, :oauth2]
    ]
  end

  defp deps do
    [
      {:oauth2, "~> 1.0 or ~> 2.0"},
      {:ueberauth, "~> 0.10"},
      {:jason, "~> 1.0"},

      # dev/test dependencies
      {:credo, "~> 1.5", only: [:dev, :test]},
      {:earmark, "~> 1.3", only: :dev},
      {:ex_doc, "~> 0.21", only: :dev},
      {:exvcr, "~> 0.11", only: :test},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:hackney, "~> 1.18", only: [:dev, :test]}
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "README",
      canonical: "http://hexdocs.pm/ueberauth_slack_oidc",
      source_url: "https://github.com/AccessOwl/ueberauth_slack_oidc",
      extras: [
        "README.md": [filename: "README"],
        "CHANGELOG.md": [filename: "CHANGELOG"]
      ]
    ]
  end

  defp package do
    [
      files: ~w(lib LICENSE mix.exs README.md),
      maintainers: ["Mathias Nestler"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/AccessOwl/ueberauth_slack_oidc"}
    ]
  end
end
