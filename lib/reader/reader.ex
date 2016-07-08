defmodule Lisp.Reader do
  @moduledoc """
    Contains functions that read and evaluate Lisp code.
  """

  alias Lisp.Types
  alias Lisp.Reader.Eval

  @spec tokenise(String.t) :: [String.t]
  defp tokenise(expr) do
    expr
    |> String.replace("(", " ( ")
    |> String.replace(")", " ) ")
    |> String.split("\"")
    |> Enum.flat_map(&String.split/1)
  end

  @spec atomise(String.t) :: Types.valid_term
  defp atomise(token) do
    cond do
      # If the token contains whitespace, it's not a bloody token.
      token =~ ~r/\s/ ->
        raise "Unexpected whitespace found in token: #{token}"
      # If the token contains digits separated by a decimal point
      token =~ ~r/^\d+\.\d+$/ ->
        String.to_float token
      # If the token contains only digits
      token =~ ~r/^\d+$/ ->
        String.to_integer token
      # If the token is enclosed in double quotes
      token =~ ~r/^".+"$/ ->
        String.slice(token, 1, String.length(token) - 2)
      # If the token is a valid identifier
      token =~ ~r/^[^\d\(\)\.',@#][^\(\)\.`',@#]*$/ ->
        String.to_atom token
      :else ->
        raise "Cannot parse token: #{token}"
    end
  end

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  @spec read([String.t]) :: [Types.valid_term]
  defp read([]) do
    []
  end

  defp read(["(" | _tokens] = all_tokens) do
    {fst, snd} = Enum.split(all_tokens, matching_paren_index(all_tokens))
    [read(Enum.drop(fst, 1)) | read(Enum.drop(snd, 1))]
  end

  defp read([")" | _tokens]) do
    raise "Unexpected closed paren while reading"
  end

  defp read([token | tokens]) do
    [atomise(token) | read(tokens)]
  end

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  @spec matching_paren_index([String.t]) :: non_neg_integer | nil
  defp matching_paren_index(["(" | _rest] = tokens) do
    tokens
    |> Enum.with_index
    |> Enum.drop(1)
    |> do_matching_paren_index([])
  end

  @spec do_matching_paren_index([String.t], [String.t]) :: non_neg_integer | nil
  defp do_matching_paren_index([], _stack) do
    nil
  end

  defp do_matching_paren_index([{"(", _i} | tokens], stack) do
    do_matching_paren_index(tokens, ["(" | stack])
  end

  defp do_matching_paren_index([{")", i} | _tokens], []) do
    i
  end

  defp do_matching_paren_index([{")", _i} | tokens], stack) do
    do_matching_paren_index(tokens, Enum.drop(stack, 1))
  end

  defp do_matching_paren_index([_token | tokens], stack) do
    do_matching_paren_index(tokens, stack)
  end

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  @spec check_parens([String.t], [String.t]) :: boolean
  defp check_parens(tokens, stack \\ [])

  defp check_parens([], []) do
    true
  end

  defp check_parens([], [_|_]) do
    false
  end

  defp check_parens(["(" | tokens], stack) do
    check_parens(tokens, ["(" | stack])
  end

  defp check_parens([")" | _tokens], []) do
    false
  end

  defp check_parens([")" | tokens], stack) do
    check_parens(tokens, Enum.drop(stack, 1))
  end

  defp check_parens([_token | tokens], stack) do
    check_parens(tokens, stack)
  end

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  @spec read_input(pid, non_neg_integer, [String.t]) :: nil
  def read_input(env, num \\ 0, read_so_far \\ []) do
    tokens =
      "lixp(#{num})> "
      |> IO.gets
      |> tokenise

    cond do
      tokens == [":quit"] ->
        nil
      not check_parens(read_so_far ++ tokens) ->
        read_input(env, num, read_so_far ++ tokens)
      :else ->
        :ok =
          read_so_far
          |> Kernel.++(tokens)
          |> read
          |> (fn x -> apply(&Eval.eval(&1, env), x) end).()
          |> IO.puts
        read_input(env, num + 1, [])
    end
  end
end
