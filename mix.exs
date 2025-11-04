defmodule Triage.MixProject do
  use Mix.Project

  @source_url "https://github.com/cheerfulstoic/triage"

  def project do
    [
      app: :triage,
      version: "0.2.5",
      elixir: "~> 1.15",
      description: "Making dealing with results (ok/error) easy",
      licenses: ["MIT"],
      package: package(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs()
    ]
  end

  defp package do
    [
      maintainers: ["Brian Underwood"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        Changelog: "#{@source_url}/blob/main/CHANGELOG.md"
      }
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs do
    [
      extra_section: "GUIDES",
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      extras: [
        # "guides/introduction/Getting Started.md",
        "README.md",
        "guides/introduction/Contexts.md",
        "guides/introduction/Enumerating Errors.md",
        "guides/introduction/Control Flow.md",
        "guides/introduction/Comparison to with.md",
        "guides/introduction/Philosophy.md",
        "guides/introduction/Logging JSON.md",
        "guides/introduction/Configuration.md",
        "guides/examples/find_working_url.md",
        "CHANGELOG.md"
      ],
      groups_for_extras: [
        Introduction: ~r/guides\/introduction\/.?/,
        "More Complicated Examples": ~r/guides\/examples\/.?/
      ],
      main: "README"
      # api_reference: false
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mix_test_interactive, "~> 5.0", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: :dev},
      {:ecto, "~> 3.0", only: :test, runtime: false},
      {:jason, "~> 1.4", optional: true},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true}

      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
