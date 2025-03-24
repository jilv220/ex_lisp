defmodule ExLisp.Repl do
  @moduledoc """
  A Read-Eval-Print Loop (REPL) for the ExLisp interpreter.
  This module provides an interactive interface to the ExLisp interpreter.
  """

  alias ExLisp.Parser
  alias ExLisp.Evaluator

  @prompt "exlisp> "
  @history_file ".exlisp_history"
  @max_history 100

  @doc """
  Starts the REPL session.
  """
  def start do
    IO.puts("ExLisp REPL - Press Ctrl+C to exit")
    loop(%{})
  end

  # Main REPL loop
  defp loop(env) do
    input = IO.gets(@prompt) |> String.trim()

    if input == "" do
      loop(env)
    else
      # Always append non-empty input to history file
      append_to_history(input)

      case input do
        clear_input when clear_input in [":clear", ":cls"] ->
          IO.write(IO.ANSI.clear() <> IO.ANSI.home())
          loop(env)

        ":history" ->
          history = load_history()
          display_history(history)
          loop(env)

        ":help" ->
          IO.puts("Available commands:")
          IO.puts(":clear or :cls - Clear the screen")
          IO.puts(":history - Show command history")
          IO.puts(":reset - Reset the environment")
          IO.puts(":exit or :q - Exit the REPL")
          IO.puts(":help - Show this help message")
          loop(env)

        ":reset" ->
          IO.puts("Environment reset.")
          loop(%{})

        quit_input when quit_input in [":exit", ":q"] ->
          # History already saved; no need to save again
          :ok

        _ ->
          case process_input(input, env) do
            {:ok, result, new_env} ->
              IO.puts(format_result(result))
              loop(new_env)

            {:error, message} ->
              IO.puts(message)
              loop(env)
          end
      end
    end
  end

  # Append command to history file immediately
  defp append_to_history(command) do
    home = System.user_home()
    path = Path.join(home, @history_file)
    File.write(path, command <> "\n", [:append])
    command
  end

  # Load the last @max_history commands from the history file
  defp load_history do
    home = System.user_home()
    path = Path.join(home, @history_file)

    if File.exists?(path) do
      File.stream!(path)
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 != ""))
      |> Enum.reverse()
      |> Enum.take(@max_history)
      |> Enum.reverse()
    else
      []
    end
  end

  # Display history with indices
  defp display_history(history) do
    if history == [] do
      IO.puts("History is empty")
    else
      history
      |> Enum.with_index(1)
      |> Enum.each(fn {cmd, idx} -> IO.puts("#{idx}: #{cmd}") end)
    end
  end

  # Process input and return structured result
  defp process_input(input, env) do
    case Parser.parse(input) do
      {:ok, expr} ->
        try do
          {result, new_env} = Evaluator.eval(expr, env)
          {:ok, result, new_env}
        rescue
          e in RuntimeError ->
            {:error, "Error: #{e.message}"}

          e ->
            {:error, "Unexpected error: #{inspect(e)}"}
        end

      {:error, reason} ->
        {:error, "Parse error: #{reason}"}
    end
  end

  # Format evaluation results
  defp format_result(nil), do: "nil"
  defp format_result(%ExLisp.Lambda{name: name}) when is_binary(name), do: "#<Function: #{name}>"
  defp format_result(%ExLisp.Lambda{}), do: "#<Lambda>"
  defp format_result(result), do: inspect(result)
end
