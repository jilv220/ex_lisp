defmodule ExLisp.Parser do
  @moduledoc """
  Parser for Lisp expressions.
  """
  @integer_regex ~r"^-?\d+$"
  @float_regex ~r"^-?\d+\.\d+$"

  # Define valid lisp operators and special forms
  @arithmetic_symbols ["+", "-", "*", "/", "mod", "rem"]
  @comparison_symbols ["=", "<", ">", "<=", ">="]
  @logical_symbols ["and", "or", "not"]
  @special_symbols ["if", "cond", "define", "lambda", "let", "quote"]
  @list_symbols ["car", "cdr", "cons", "list"]

  @valid_symbols @arithmetic_symbols ++
                   @comparison_symbols ++ @logical_symbols ++ @special_symbols ++ @list_symbols

  @type token :: integer() | float() | boolean() | atom()
  @type expression :: token() | [expression()]

  @spec parse_token(String.t()) :: token()
  @doc """
  Converts a string token into its corresponding Elixir value
  ## Examples

      iex> ExLisp.Parser.parse_token("42")
      42

      iex> ExLisp.Parser.parse_token("+")
      :+

      iex> ExLisp.Parser.parse_token("3.14")
      3.14

      iex> ExLisp.Parser.parse_token("define")
      :define

      iex> ExLisp.Parser.parse_token("x")
      "x"

      iex> ExLisp.Parser.parse_token("my-variable")
      "my-variable"
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

      token in @valid_symbols ->
        String.to_atom(token)

      # Keep other identifiers as strings (for variables)
      true ->
        token
    end
  end

  @spec tokenize(String.t()) :: [String.t()]
  @doc """
  Converts a Lisp expression string into a list of tokens.

  ## Examples

      iex> ExLisp.Parser.tokenize("(+ 1 2)")
      ["(", "+", "1", "2", ")"]

      iex> ExLisp.Parser.tokenize("(* (+ 2 3) 4)")
      ["(", "*", "(", "+", "2", "3", ")", "4", ")"]

      iex> ExLisp.Parser.tokenize("")
      []

      iex> ExLisp.Parser.tokenize("42")
      ["42"]
  """
  def tokenize(input) do
    input
    |> String.replace("(", " ( ")
    |> String.replace(")", " ) ")
    |> String.split()
    |> Enum.filter(&(&1 != ""))
  end

  @spec parse(String.t()) :: {:ok, expression()} | {:error, String.t()}
  @doc """
  Parses a Lisp expression string into its Elixir representation.

  Returns `{:ok, expression}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> ExLisp.Parser.parse("42")
      {:ok, 42}

      iex> ExLisp.Parser.parse("(+ 1 2)")
      {:ok, [:+, 1, 2]}

      iex> ExLisp.Parser.parse("(+ 1 (* 2 3))")
      {:ok, [:+, 1, [:*, 2, 3]]}

      iex> ExLisp.Parser.parse("(define x 10)")
      {:ok, [:define, "x", 10]}

      iex> ExLisp.Parser.parse("(+ 1 2")
      {:error, "Missing closing parenthesis"}

      iex> ExLisp.Parser.parse("")
      {:error, "Unexpected end of input"}
  """
  def parse(code) when is_binary(code) do
    tokens = tokenize(code)

    case parse_tokens(tokens) do
      {:ok, {expr, []}} -> {:ok, expr}
      {:ok, {_expr, remaining}} -> {:error, "Unexpected extra tokens: #{inspect(remaining)}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec parse!(String.t()) :: expression()
  @doc """
  Parses a Lisp expression string into its Elixir representation.

  Similar to `parse/1` but raises an exception on error.

  ## Examples

      iex> ExLisp.Parser.parse!("42")
      42

      iex> ExLisp.Parser.parse!("(+ 1 (* 2 3))")
      [:+, 1, [:*, 2, 3]]

      iex> try do
      ...>   ExLisp.Parser.parse!("(+ 1")
      ...> rescue
      ...>   e in ArgumentError -> e.message
      ...> end
      "Missing closing parenthesis"
  """
  def parse!(code) when is_binary(code) do
    case parse(code) do
      {:ok, expr} -> expr
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc false
  @spec parse_tokens([String.t()]) :: {:ok, {expression(), [String.t()]}} | {:error, String.t()}
  def parse_tokens([]) do
    {:error, "Unexpected end of input"}
  end

  def parse_tokens(["(" | rest]) do
    parse_list(rest, [])
  end

  def parse_tokens([token | rest]) do
    {:ok, {parse_token(token), rest}}
  end

  @doc false
  @spec parse_list([String.t()], [expression()]) ::
          {:ok, {[expression()], [String.t()]}} | {:error, String.t()}
  # Base case 1: End of a list - we found a closing parenthesis
  def parse_list([")" | rest], acc) do
    {:ok, {Enum.reverse(acc), rest}}
  end

  # Base case 2: Unexpected end of input (missing closing parenthesis)
  def parse_list([], _acc) do
    {:error, "Missing closing parenthesis"}
  end

  # Recursive case 1: Start of a nested list
  def parse_list(["(" | rest], acc) do
    case parse_list(rest, []) do
      {:ok, {subexpr, remaining}} -> parse_list(remaining, [subexpr | acc])
      {:error, reason} -> {:error, reason}
    end
  end

  # Recursive case 2: Regular token
  def parse_list([token | rest], acc) do
    parse_list(rest, [parse_token(token) | acc])
  end
end
