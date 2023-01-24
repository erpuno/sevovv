defmodule ECSV.Mixfile do
  use Mix.Project

  def project() do
    [
      app: :ecsv,
      elixirc_options: [warnings_as_errors: true],
      compilers: [:elixir_make | Mix.compilers()],
      make_makefile: "c_src/Makefile",
      package: package(),
      version: "1.4.2",
      elixir: "~> 1.9",
      description: "CSV Stream Parser",
      package: package(),
      deps: deps()
    ]
  end

  def package do
    [
      files: ~w(doc src c_src priv rebar.config mix.exs LICENSE),
      licenses: ["ISC"],
      maintainers: ["Namdak Tonpa"],
      name: :ecsv,
      links: %{"GitHub" => "https://github.com/erpuno/ecsv"}
    ]
  end

  def application() do
    [mod: {:ecsv, []}]
  end

  def deps() do
    [
      {:elixir_make, "~> 0.6.0", runtime: false},
      {:ex_doc, "~> 0.11", only: :dev}
    ]
  end
end
