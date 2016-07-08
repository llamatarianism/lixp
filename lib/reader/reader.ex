defmodule Lisp.Reader do
  @moduledoc """
    Contains functions that read and evaluate Lisp code.
  """

  alias Lisp.Types
  alias Lisp.Reader.Eval
  alias Lisp.Lambda

  @spec tokenise(String.t) :: [String.t]
  def tokenise(expr) do
    expr
    |> String.replace(~r/([\{\}\(\)])/, " \\1 ")
    |> String.split
  end

  @spec atomise(String.t) :: Types.valid_term
  def atomise(token) do
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
      token =~ "true" ->
        true
      token =~ "false" ->
        false
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
  def read([]) do
    []
  end

  def read(["(" | _tokens] = all_tokens) do
    {fst, snd} = Enum.split(all_tokens, matching_paren_index(all_tokens))
    [read(Enum.drop(fst, 1)) | read(Enum.drop(snd, 1))]
  end

  def read([")" | _tokens]) do
    raise "Unexpected list delimiter while reading"
  end

  def read(["{" | _tokens] = all_tokens) do
    {fst, snd} = Enum.split(all_tokens, matching_paren_index(all_tokens, {"{", "}"}))
    [[:tuple | read(Enum.drop(fst, 1))] | read(Enum.drop(snd, 1))]
  end

  def read(["}" | _tokens]) do
    raise "Unexpected tuple delimiter while reading"
  end

  def read([token | tokens]) do
    [atomise(token) | read(tokens)]
  end

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  @spec matching_paren_index([String.t], {String.t, String.t}) :: non_neg_integer | nil
  defp matching_paren_index(tokens, type \\ {"(", ")"}) do
    tokens
    |> Enum.with_index
    |> Enum.drop(1)
    |> do_matching_paren_index([], type)
  end

  @spec do_matching_paren_index([String.t], [String.t], {String.t, String.t}) :: non_neg_integer | nil
  defp do_matching_paren_index([], _stack, _type) do
    nil
  end

  defp do_matching_paren_index([{open, _i} | tokens], stack, {open, _close} = type) do
    do_matching_paren_index(tokens, [open | stack], type)
  end

  defp do_matching_paren_index([{close, i} | _tokens], [], {_open, close}) do
    i
  end

  defp do_matching_paren_index([{close, _i} | tokens], stack, {_open, close} = type) do
    do_matching_paren_index(tokens, Enum.drop(stack, 1), type)
  end

  defp do_matching_paren_index([_token | tokens], stack, type) do
    do_matching_paren_index(tokens, stack, type)
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

defp lispy_print(list) when is_list(list) do
  list
  |> Enum.map(&lispy_print/1)
  |> Enum.join(" ")
  |> (fn s -> "(#{s})" end).()
end

defp lispy_print(tuple) when is_tuple(tuple) do
  tuple
  |> Tuple.to_list
  |> Enum.map(&lispy_print/1)
  |> Enum.join(" ")
  |> (fn s -> "{#{s}}" end).()
end

defp lispy_print(str) when is_binary(str) do
  "\"" <> str <> "\""
end

defp lispy_print(%Lambda{params: params, body: body}) do
  "<Lambda | Params: #{Enum.map(params, &lispy_print/1)} | Body: #{lispy_print(body)}>"
end

defp lispy_print(nil) do
  "nil"
end

defp lispy_print(term) do
  to_string term
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
        read_so_far
        |> Kernel.++(tokens)
        |> read
        |> (fn x -> apply(&Eval.eval(&1, env), x) end).()
        |> lispy_print
        |> IO.puts
        read_input(env, num + 1, [])
    end
  end
end
