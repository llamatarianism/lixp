defmodule Lisp.Reader.Eval do
  alias Lisp.Types
  alias Lisp.Env
  alias Lisp.Lambda

  @spec eval([Types.valid_term] | Types.valid_term, map) :: any
  def eval([:define, sym | body], env) when is_atom(sym) do
    Env.define(env, sym, apply(&eval(&1, env), body))
  end

  def eval([:define, [f | params] | body], env) do
    Env.define(env, f, %Lambda{params: params, body: body, env: env})
  end

  def eval([:quote, arg], _env) do
    arg
  end

  def eval([f | args], env) do
    partially_evaluated = Enum.map(args, fn
    # If the argument is a list, `eval` it as well.
      ([_x | _xs] = arg) ->
        eval(arg, env)
    # If the argument is a symbol, look it up in the env.
      arg when is_atom(arg) ->
        Env.lookup(env, arg)
    # Otherwise, just return it.
      arg ->
        arg
    end)
    env_f = Env.lookup(env, f)
    if is_function(env_f) do
      env_f.(partially_evaluated)
    else
      Lambda.call env_f, partially_evaluated
    end
  end

  def eval(term, env) when is_atom(term) do
    Env.lookup(env, term)
  end

  def eval(term, _env) do
    term
  end
end
