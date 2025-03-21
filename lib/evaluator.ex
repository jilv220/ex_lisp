defmodule ExLisp.Evaluator do
  @moduledoc """
  Evaluator for Lisp expressions.

  This module provides functionality to evaluate parsed Lisp expressions
  within an environment of defined variables and functions.
  """
  alias ExLisp.Parser

  @type env :: %{required(String.t()) => any()}
  @type expression :: Parser.expression()

  defmacro is_token(expr) do
    quote do
      is_atom(unquote(expr)) or is_boolean(unquote(expr)) or
        is_float(unquote(expr)) or is_integer(unquote(expr))
    end
  end

  @doc """
  Evaluates a Lisp expression in the given environment.

  Returns a tuple of {result, updated_environment}.

  ## Examples
      iex> ExLisp.Evaluator.eval(42, %{})
      {42, %{}}

      iex> ExLisp.Evaluator.eval([:+, 1, 2], %{})
      {3, %{}}

      iex> ExLisp.Evaluator.eval([:and, true, false], %{})
      {false, %{}}

      iex> ExLisp.Evaluator.eval("x", %{"x" => 10})
      {10, %{"x" => 10}}
  """
  @spec eval(expression(), env()) :: {any(), env()}
  def eval(expr, env \\ %{})

  # Base values evaluate to themselves
  def eval(expr, env) when is_token(expr), do: {expr, env}

  # Variable lookup
  def eval(var, env) when is_binary(var), do: eval_variable(var, env)

  # Dispatcher for different expression types
  def eval([op | args], env) when op in [:+, :-, :*, :/, :mod, :rem],
    do: eval_arithmetic(op, args, env)

  def eval([op | args], env) when op in [:and, :or, :not], do: eval_logical(op, args, env)

  def eval([:if | args], env), do: eval_if(args, env)

  # Catch-all for unhandled expressions
  def eval(expr, _env), do: raise("Unrecognized expression: #{inspect(expr)}")

  #
  # Variable handling
  #
  defp eval_variable(var, env) do
    case Map.fetch(env, var) do
      {:ok, value} -> {value, env}
      :error -> raise "Undefined variable: #{var}"
    end
  end

  #
  # Arithmetic operations
  #
  defp eval_arithmetic(op, args, env) do
    {evaluated_args, new_env} = eval_args(args, env)

    unless Enum.all?(evaluated_args, &is_number/1) do
      raise "All arguments to #{op} must be numbers"
    end

    result = apply_arithmetic(op, evaluated_args)
    {result, new_env}
  end

  defp apply_arithmetic(:+, args), do: Enum.sum(args)

  defp apply_arithmetic(:-, [x]), do: -x

  defp apply_arithmetic(:-, [x, y | rest]),
    do: Enum.reduce(rest, x - y, fn val, acc -> acc - val end)

  defp apply_arithmetic(:*, args), do: Enum.reduce(args, 1, &(&1 * &2))

  defp apply_arithmetic(:/, [_, 0 | _]), do: raise("Division by zero")

  defp apply_arithmetic(:/, [x, y | rest]),
    do: Enum.reduce(rest, x / y, fn val, acc -> acc / val end)

  defp apply_arithmetic(:mod, [x, y]), do: Integer.mod(x, y)
  defp apply_arithmetic(:mod, _), do: raise("mod requires exactly 2 arguments")

  defp apply_arithmetic(:rem, [x, y]), do: rem(x, y)
  defp apply_arithmetic(:rem, _), do: raise("rem requires exactly 2 arguments")

  #
  # Logical operations
  #
  defp eval_logical(:and, args, env), do: eval_and(args, env)
  defp eval_logical(:or, args, env), do: eval_or(args, env)

  defp eval_logical(:not, [arg], env) do
    {val, new_env} = eval(arg, env)
    {to_boolean(val) |> Kernel.not(), new_env}
  end

  defp eval_logical(:not, _, _), do: raise("not requires exactly 1 argument")

  # Evaluate 'and' with short-circuit semantics
  defp eval_and([], env), do: {true, env}

  defp eval_and([arg | rest], env) do
    {value, new_env} = eval(arg, env)

    if to_boolean(value) do
      if rest == [], do: {value, new_env}, else: eval_and(rest, new_env)
    else
      # Short-circuit with the first falsy value
      {value, new_env}
    end
  end

  # Evaluate 'or' with short-circuit semantics
  defp eval_or([], env), do: {false, env}

  defp eval_or([arg | rest], env) do
    {value, new_env} = eval(arg, env)

    if to_boolean(value) do
      # Short-circuit with the first truthy value
      {value, new_env}
    else
      if rest == [], do: {value, new_env}, else: eval_or(rest, new_env)
    end
  end

  #
  # Special forms
  #

  # If with explicit else branch
  defp eval_if([condition, then_expr, else_expr], env) do
    {condition_val, new_env} = eval(condition, env)

    if to_boolean(condition_val) do
      eval(then_expr, new_env)
    else
      eval(else_expr, new_env)
    end
  end

  # If with implicit nil for else branch
  defp eval_if([condition, then_expr], env) do
    {condition_val, new_env} = eval(condition, env)

    if to_boolean(condition_val) do
      eval(then_expr, new_env)
    else
      {nil, new_env}
    end
  end

  # Invalid if form
  defp eval_if(args, _env),
    do: raise("Invalid 'if' form, expected 2-3 arguments, got: #{length(args)}")

  #
  # Helpers
  #

  @doc false
  defp eval_args(args, env) do
    Enum.reduce(args, {[], env}, fn arg, {acc, current_env} ->
      {value, updated_env} = eval(arg, current_env)
      {acc ++ [value], updated_env}
    end)
  end

  # Helper to convert any value to a boolean based on Lisp truthiness rules
  defp to_boolean(nil), do: false
  defp to_boolean(false), do: false
  defp to_boolean(_), do: true
end
