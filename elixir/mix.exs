defmodule AtuinStand.MixProject do
  use Mix.Project

  def project do
    [
      app: :atuin_stand,
      version: "0.1.1",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "An Elixir implementation of the `atuin-stand` project.",
      source_url: "https://github.com/atuinsh/atuin-stand/elixir",
      docs: [
        main: "readme",
        extras: ["README.md": [title: "AtuinStand"]],
        source_ref: "master",
        source_url: "https://github.com/atuinsh/atuin-stand/elixir",
        before_closing_head_tag: &doc_styles/1
      ],
      package: [
        licenses: ["MIT"],
        links: %{
          "GitHub" => "https://github.com/atuinsh/atuin-stand/elixir"
        }
      ]
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end

  defp doc_styles(:html) do
    """
    <style type="text/css">
    .content-inner code.text {
      font-family: Menlo, monospace;
      line-height: 1.3em;
    }

    .content-inner h1 code {
      font-size: 32px !important;
    }
    </style>
    """
  end

  defp doc_styles(_), do: ""
end
