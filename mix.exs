defmodule ReqTelemetry.MixProject do
  use Mix.Project

  @name "ReqTelemetry"
  @version "0.0.4"
  @source_url "https://github.com/zachallaun/req_telemetry"

  def project do
    [
      app: :req_telemetry,
      name: @name,
      version: @version,
      source_url: @source_url,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: [
        docs: :docs,
        "hex.publish": :docs
      ],
      docs: docs(),
      package: [
        description: "Req plugin to instrument requests with Telemetry events",
        licenses: ["MIT"],
        links: %{
          "GitHub" => @source_url
        }
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5.0"},
      {:telemetry, "~> 1.0"},
      {:ex_doc, ">= 0.31.0", only: :docs}
    ]
  end

  defp docs do
    [
      source_url: @source_url,
      main: "ReqTelemetry",
      extras: [
        "README.md": [title: "Overview"],
        "CHANGELOG.md": [title: "Changelog"]
      ]
    ]
  end
end
