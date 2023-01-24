defmodule SMTP.Mixfile do
  use Mix.Project

  def project() do
    [
      app: :smtp,
      version: "1.1.2",
      elixir: "~> 1.9",
      description: "SMTP Client and Server",
      package: package(),
      deps: deps()
    ]
  end

  def package do
    [
      files: ~w(src mix.exs LICENSE),
      licenses: ["ISC"],
      maintainers: ["Namdak Tonpa"],
      name: :smtp,
      links: %{"GitHub" => "https://github.com/erpuno/smtp"}
    ]
  end

  def application() do
    [
      mod: {:smtp, []},
      applications: [:kernel,:stdlib,:crypto,:asn1,:public_key,:ssl,:ranch]
    ]
  end

  def deps() do
    [
      {:ranch, "~> 1.8.0"},
      {:hut, "~> 1.3.0"},
      {:ex_doc, "~> 0.11", only: :dev}
    ]
  end
end
