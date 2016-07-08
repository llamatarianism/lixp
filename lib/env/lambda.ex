defmodule Lisp.Lambda do
  alias Lisp.Reader.Eval
  alias Lisp.Env

  defstruct params: [], body: [], env: %{}

  def call(%Lisp.Lambda{params: params, body: body, env: env}, args) do
    {:ok, new_env} =
      params
      |> Enum.zip(args)
      |> Map.new
      |> Map.merge(if is_pid(env), do: Env.all_vars(env), else: env)
      |> Env.start_link


    apply(&Eval.eval(&1, new_env), body)
  end

  def call(nil, _args) do
    raise "SyntaxError: undefined function call"
  end
end
