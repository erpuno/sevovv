defmodule Sax.MixProject do
  use Mix.Project
  def project() do
    [
      app: :sax,
      version: "1.0.0",
      elixir: "~> 1.6",
      description: "An XML SAX parser and encoder in Elixir.",
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      package: package(),
      name: "sax",
      docs: docs()
    ]
  end

  def application(), do: []

  defp package() do
    [
      maintainers: ["TotallyNotMay"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/TotallyNotMay/sax"}
    ]
  end

  defp deps() do
    [
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},
      {:stream_data, "~> 0.4.2", only: :test}
    ]
  end

  defp docs() do
    [
      main: "Sax",
      source_ref: "1.0.0",
      source_url: "https://github.com/TotallyNotMay/sax"
    ]
  end
end
