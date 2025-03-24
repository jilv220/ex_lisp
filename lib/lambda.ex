defmodule ExLisp.Lambda do
  @moduledoc """
  Structure representing a lambda procedure in the Lisp interpreter.
  """
  defstruct [:params, :body, :env, :name]

  @type t :: %__MODULE__{
          params: [String.t()],
          body: ExLisp.Parser.expression(),
          env: ExLisp.Evaluator.env()
        }
end
