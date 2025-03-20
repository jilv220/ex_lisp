defmodule Parser do
  @moduledoc """
  * Lisp Expression: Either an atom or a list
  * Lisp Atom: Simple value (number, symbol)
  * Lisp List: Compound expression in parentheses
  * Lisp Symbol: Represented as Elixir atom (e.g., + becomes :+)
  """
  @integer_regex ~r"^-?\d+$"
  @float_regex ~r"^-?\d+.\d+$"

  @type token :: integer() | float() | boolean() | atom()

  @spec parse_token(String.t()) :: token()
  @doc """
  Converts a string token into its corresponding Elixir value
  """
  def parse_token(token) when is_binary(token) do
    cond do
      token =~ @integer_regex ->
        String.to_integer(token)

      token =~ @float_regex ->
        String.to_float(token)

      token == "true" ->
        true

      token == "false" ->
        false

      # Default to atom for now
      true ->
        String.to_atom(token)
    end
  end

  def tokenize(input) do
    input
    |> String.replace("(", " ( ")
    |> String.replace(")", " ) ")
    |> String.split()
    |> Enum.filter(&(&1 != ""))
  end
end
