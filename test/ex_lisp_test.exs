defmodule ExLispTest do
  use ExUnit.Case
  doctest ExLisp

  test "greets the world" do
    assert ExLisp.hello() == :world
  end
end
