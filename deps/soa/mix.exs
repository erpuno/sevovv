defmodule Soap.MixProject do
  use Mix.Project

  def project do
    [
      app: :soa,
      version: "0.1.7",
      deps: deps(),
      package: package(),
      description: "SOA Simple Object Access Protocol",
    ]
  end

  def deps, do: [{:ex_doc, "~> 0.11", only: :dev}]
  def application, do: [extra_applications: [:logger] ]
  def package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Maxim Sokhatsky"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/erpuno/soa"}
    ]
  end
end
