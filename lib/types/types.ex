defmodule Lisp.Types do
  @moduledoc """
    Types that are used by several different modules for specifications.
  """
  @type valid_term :: atom
    | String.t
    | float
    | integer
    | nil
    | [valid_term]
    | struct
    | tuple
end
