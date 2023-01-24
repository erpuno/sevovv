defmodule SEVOVV.Mixfile do
  use Mix.Project

  def project do
    [
      app: :sevovv,
      version: "0.1.0",
      description: "SEVOVV DIIA National Wide State Enterprise Document Bus",
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [mod: {SEVOVV, []}, applications: [:logger, :schema, :form, :nitro, :n2o, :kvs, :sax, :soa, :jsone, :bpe]]
  end

  def package do
    [
      files: ~w(lib mix.exs),
      licenses: ["ISC"],
      maintainers: ["Namdak Tonpa"],
      name: :sevovv,
      links: %{"GitHub" => "https://github.com/erpuno/sevovv"}
    ]
  end

  def deps do
    [
      {:ex_doc, "~> 0.11", only: :dev},
      {:jsone, "~> 1.5.1"},
      {:schema, "~> 4.1.0"},
      {:soa, "~> 0.1.7"},
      {:smtp, "~> 1.1.2"},
      {:nitro, "7.12.1", override: true},
      {:ecsv, "~> 1.4.2"},
      {:bpe, "7.10.4"},
      {:sax, "~> 1.0.0"},
      {:form, "7.8.0"},
      {:rocksdb, "~> 1.6.0"},
      {:n2o, "~> 8.12.1"}
    ]
  end
end
