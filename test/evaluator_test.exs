defmodule ExLisp.EvaluatorTest do
  use ExUnit.Case, async: true
  doctest ExLisp.Evaluator

  alias ExLisp.Parser
  alias ExLisp.Evaluator
  alias ExLisp.Lambda

  # Helper function to parse and evaluate expressions
  defp parse_eval(code, env \\ %{}) do
    {:ok, ast} = Parser.parse(code)
    Evaluator.eval(ast, env)
  end

  describe "literals" do
    test "evaluates numeric literals" do
      assert {42, %{}} == parse_eval("42")
      assert {-7, %{}} == parse_eval("-7")
      assert {3.14, %{}} == parse_eval("3.14")
    end

    test "evaluates boolean literals" do
      assert {true, %{}} == parse_eval("true")
      assert {false, %{}} == parse_eval("false")
    end
  end

  describe "arithmetic operations" do
    test "addition" do
      assert {3, %{}} == parse_eval("(+ 1 2)")
      assert {10, %{}} == parse_eval("(+ 1 2 3 4)")
      assert {0, %{}} == parse_eval("(+ 0)")
      assert {0, %{}} == parse_eval("(+)")
    end

    test "subtraction" do
      assert {-1, %{}} == parse_eval("(- 1)")
      assert {-1, %{}} == parse_eval("(- 1 2)")
      assert {10, %{}} == parse_eval("(- 20 5 3 2)")
    end

    test "multiplication" do
      assert {6, %{}} == parse_eval("(* 2 3)")
      assert {24, %{}} == parse_eval("(* 2 3 4)")
      assert {1, %{}} == parse_eval("(*)")
    end

    test "division" do
      assert {2.5, %{}} == parse_eval("(/ 5 2)")
      assert {2.0, %{}} == parse_eval("(/ 20 5 2)")

      assert_raise RuntimeError, "Division by zero", fn ->
        parse_eval("(/ 10 0)")
      end
    end

    test "modulo" do
      assert {1, %{}} == parse_eval("(mod 5 2)")
      assert {0, %{}} == parse_eval("(mod 10 5)")

      assert_raise RuntimeError, "mod requires exactly 2 arguments", fn ->
        parse_eval("(mod 10 5 2)")
      end
    end

    test "remainder" do
      assert {1, %{}} == parse_eval("(rem 5 2)")
      assert {-1, %{}} == parse_eval("(rem -5 2)")

      assert_raise RuntimeError, "rem requires exactly 2 arguments", fn ->
        parse_eval("(rem 10)")
      end
    end

    test "nested arithmetic" do
      assert {11, %{}} == parse_eval("(+ (* 2 3) (- 10 5))")
      assert {20, %{}} == parse_eval("(* (+ 2 3) (- 10 6))")
    end
  end

  describe "logical operations" do
    test "and operation" do
      assert {true, %{}} == parse_eval("(and true true)")
      assert {false, %{}} == parse_eval("(and true false)")
      assert {false, %{}} == parse_eval("(and false true)")
      assert {true, %{}} == parse_eval("(and)")
      # Short-circuit evaluation
      assert {false, %{}} == parse_eval("(and false (/ 1 0))")
    end

    test "or operation" do
      assert {true, %{}} == parse_eval("(or true false)")
      assert {true, %{}} == parse_eval("(or false true)")
      assert {false, %{}} == parse_eval("(or false false)")
      assert {false, %{}} == parse_eval("(or)")
      # Short-circuit evaluation
      assert {true, %{}} == parse_eval("(or true (/ 1 0))")
    end

    test "not operation" do
      assert {false, %{}} == parse_eval("(not true)")
      assert {true, %{}} == parse_eval("(not false)")
      # Non-false values are truthy
      assert {false, %{}} == parse_eval("(not 42)")

      assert_raise RuntimeError, "not requires exactly 1 argument", fn ->
        parse_eval("(not)")
      end
    end

    test "combined logical operations" do
      assert {true, %{}} == parse_eval("(and (or false true) true)")
      assert {false, %{}} == parse_eval("(and (or true true) (not true))")
    end
  end

  describe "if special form" do
    test "if with true condition" do
      assert {42, %{}} == parse_eval("(if true 42 0)")
    end

    test "if with false condition" do
      assert {0, %{}} == parse_eval("(if false 42 0)")
    end

    # test "if with expressions as branches" do
    #   assert {8, %{}} == parse_eval("(if (> 5 2) (+ 3 5) (- 10 5))")
    #   assert {5, %{}} == parse_eval("(if (< 5 2) (+ 3 5) (- 10 5))")
    # end

    test "if without else branch" do
      assert {42, %{}} == parse_eval("(if true 42)")
      assert {nil, %{}} == parse_eval("(if false 42)")
    end

    test "invalid if form" do
      assert_raise RuntimeError, ~r/Invalid 'if' form/, fn ->
        parse_eval("(if)")
      end

      assert_raise RuntimeError, ~r/Invalid 'if' form/, fn ->
        parse_eval("(if true 1 2 3)")
      end
    end
  end

  describe "variable binding and lookup" do
    test "variable lookup" do
      env = %{"x" => 42, "y" => 10}
      assert {42, ^env} = parse_eval("x", env)
      assert {10, ^env} = parse_eval("y", env)
    end

    test "undefined variable" do
      assert_raise RuntimeError, "Undefined variable: z", fn ->
        parse_eval("z", %{})
      end
    end
  end

  describe "define special form" do
    test "define variable" do
      {_, env} = parse_eval("(define x 42)")
      assert env["x"] == 42

      # Define and use in sequence
      {result, _} = parse_eval("(+ x 10)", env)
      assert result == 52
    end

    test "define with expression" do
      {_, env} = parse_eval("(define y (+ 2 3))")
      assert env["y"] == 5
    end

    test "redefine variable" do
      {_, env1} = parse_eval("(define z 10)")
      {_, env2} = parse_eval("(define z 20)", env1)
      assert env2["z"] == 20
    end

    test "define function" do
      {_, env} = parse_eval("(define (add x y) (+ x y))")
      assert %Lambda{} = env["add"]

      # Call the defined function
      {result, _} = parse_eval("(add A2 3)", Map.put(env, "A2", 7))
      assert result == 10
    end

    test "define and call nested functions" do
      _code = """
      (define (square x) (* x x))
      (define (sum-of-squares a b) (+ (square a) (square b)))
      (sum-of-squares 3 4)
      """

      {:ok, ast1} = Parser.parse("(define (square x) (* x x))")
      {_, env1} = Evaluator.eval(ast1)

      {:ok, ast2} = Parser.parse("(define (sum-of-squares a b) (+ (square a) (square b)))")
      {_, env2} = Evaluator.eval(ast2, env1)

      {:ok, ast3} = Parser.parse("(sum-of-squares 3 4)")
      {result, _} = Evaluator.eval(ast3, env2)

      assert result == 25
    end
  end

  describe "list operations" do
    test "list" do
      assert {[], %{}} == parse_eval("(list)")
      assert {[1, 2, 3], %{}} == parse_eval("(list 1 2 3)")
      assert {[1, [2, 3]], %{}} == parse_eval("(list 1 (list 2 3))")
    end

    test "car" do
      assert {1, %{}} == parse_eval("(car (list 1 2 3))")
      assert {1, %{}} == parse_eval("(car (cons 1 (list 2 3)))")

      assert_raise RuntimeError, ~r/car: cannot take car of empty list/, fn ->
        parse_eval("(car (list))")
      end

      assert_raise RuntimeError, ~r/car requires a list argument/, fn ->
        parse_eval("(car 42)")
      end
    end

    test "cdr" do
      assert {[2, 3], %{}} == parse_eval("(cdr (list 1 2 3))")
      assert {[], %{}} == parse_eval("(cdr (list 1))")

      assert_raise RuntimeError, ~r/cdr: cannot take cdr of empty list/, fn ->
        parse_eval("(cdr (list))")
      end

      assert_raise RuntimeError, ~r/cdr requires a list argument/, fn ->
        parse_eval("(cdr 42)")
      end
    end

    test "cons" do
      assert {[1, 2, 3], %{}} == parse_eval("(cons 1 (list 2 3))")
      assert {[1], %{}} == parse_eval("(cons 1 (list))")
      assert {[[1, 2], 3, 4], %{}} == parse_eval("(cons (list 1 2) (list 3 4))")

      assert_raise RuntimeError, ~r/cons: second argument must be a list/, fn ->
        parse_eval("(cons 1 2)")
      end
    end

    test "nested list operations" do
      assert {2, %{}} == parse_eval("(car (cdr (list 1 2 3)))")
      assert {[2], %{}} == parse_eval("(cons 2 (list))")
      assert {[1, 2, 3, 4], %{}} == parse_eval("(cons 1 (cons 2 (cons 3 (cons 4 (list)))))")
    end
  end

  describe "lambda and function application" do
    test "create simple lambda" do
      {lambda, _} = parse_eval("(lambda (x) (+ x 1))")
      assert %Lambda{} = lambda
      assert lambda.params == ["x"]
    end

    test "apply lambda directly" do
      {result, _} = parse_eval("((lambda (x) (+ x 1)) 5)")
      assert result == 6
    end

    test "lambda with multiple parameters" do
      {result, _} = parse_eval("((lambda (x y) (+ x y)) 3 4)")
      assert result == 7
    end

    test "lambda captures lexical environment" do
      _code = """
      (define x 10)
      ((lambda (y) (+ x y)) 5)
      """

      {:ok, ast1} = Parser.parse("(define x 10)")
      {_, env} = Evaluator.eval(ast1)

      {:ok, ast2} = Parser.parse("((lambda (y) (+ x y)) 5)")
      {result, _} = Evaluator.eval(ast2, env)

      assert result == 15
    end

    test "wrong number of arguments to lambda" do
      assert_raise RuntimeError, "Expected 2 arguments, got 1", fn ->
        parse_eval("((lambda (x y) (+ x y)) 5)")
      end

      assert_raise RuntimeError, "Expected 1 arguments, got 2", fn ->
        parse_eval("((lambda (x) (+ x 1)) 5 6)")
      end
    end
  end

  describe "complex scenarios" do
    test "factorial function" do
      # Define factorial function
      factorial_def = """
      (define (factorial n)
        (if (= n 0)
            1
            (* n (factorial (- n 1)))))
      """

      {:ok, ast1} = Parser.parse(factorial_def)
      {_, env} = Evaluator.eval(ast1)

      # Call factorial with different values
      {:ok, ast2} = Parser.parse("(factorial 5)")
      {result, _} = Evaluator.eval(ast2, env)
      assert result == 120

      {:ok, ast3} = Parser.parse("(factorial 0)")
      {result, _} = Evaluator.eval(ast3, env)
      assert result == 1
    end

    test "fibonacci function" do
      # Define fibonacci function
      fibonacci_def = """
      (define (fib n)
        (if (< n 2)
            n
            (+ (fib (- n 1)) (fib (- n 2)))))
      """

      {:ok, ast1} = Parser.parse(fibonacci_def)
      {_, env} = Evaluator.eval(ast1)

      # Call fibonacci with different values
      {:ok, ast2} = Parser.parse("(fib 0)")
      {result, _} = Evaluator.eval(ast2, env)
      assert result == 0

      {:ok, ast3} = Parser.parse("(fib 1)")
      {result, _} = Evaluator.eval(ast3, env)
      assert result == 1

      {:ok, ast4} = Parser.parse("(fib 5)")
      {result, _} = Evaluator.eval(ast4, env)
      assert result == 5

      # This would be slow for larger values due to the naive recursion
      {:ok, ast5} = Parser.parse("(fib 10)")
      {result, _} = Evaluator.eval(ast5, env)
      assert result == 55
    end
  end
end
