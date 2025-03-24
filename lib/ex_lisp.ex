defmodule ExLisp do
  @moduledoc """
  Documentation for `ExLisp`.
  """
  alias ExLisp.Repl

  def main(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        aliases: [h: :help, v: :version],
        switches: [help: :boolean, version: :boolean]
      )

    cond do
      opts[:help] ->
        print_help()

      opts[:version] ->
        print_version()

      true ->
        Repl.start()
    end
  end

  defp print_help do
    IO.puts("""
    ExLisp - A simple Lisp interpreter written in Elixir

    Usage:
      exlisp [options]

    Options:
      -h, --help      Show this help message
      -v, --version   Show version information
    """)
  end

  defp print_version do
    {:ok, vsn} = :application.get_key(:ex_lisp, :vsn)
    IO.puts("ExLisp version #{vsn}")
  end
end
