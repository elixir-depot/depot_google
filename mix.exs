defmodule DepotGoogle.MixProject do
  use Mix.Project

  def project do
    [
      app: :depot_google,
      version: "0.0.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      description: description(),
      package: package(),
      name: "Depot Google",
      source_url: "https://github.com/elixir-depot/depot_google"
    ]
  end

  defp description() do
    "Depot adapter for Google Cloud Storage."
  end

  defp package() do
    [
      # These are the default files included in the package
      files: ~w(lib mix.exs README* LICENSE*),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/elixir-depot/depot_google"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:depot, "~> 0.2.2"},
      {:goth, "~> 1.2"},
      {:google_api_storage, "~> 0.22"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end
end
