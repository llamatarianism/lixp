defmodule LispTest do
  use ExUnit.Case
  doctest Lisp

  test "the truth" do
    assert 1 + 1 == 2
  end
end
