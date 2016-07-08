defmodule Lisp.Reader.Eval do
  alias Lisp.Types
  alias Lisp.Env
  alias Lisp.Lambda

  @spec eval(Types.valid_term, pid) :: Types.valid_term | no_return
  def eval([:define, sym | body], env) when is_atom(sym) do
    Env.define(env, sym, apply(&eval(&1, env), body))
  end

  def eval([:define, [f | params] | body], env) do
    Env.define(env, f, %Lambda{params: params, body: body, env: env})
  end

  def eval([:lambda, params | body], env) do
    %Lambda{params: params, body: body, env: env}
  end

  def eval([:quote, arg], _env) do
    arg
  end

  def eval([:if, condition, then_form, else_form], env) do
    if eval(condition, env) == true do
      eval(then_form, env)
    else
      eval(else_form, env)
    end
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

    case Env.lookup(env, f) do
      fun when is_function(fun) ->
        fun.(partially_evaluated)
      lambda = %Lambda{} ->
        Lambda.call(lambda, partially_evaluated)
      _ ->
        Lambda.call(eval(f, env), partially_evaluated)
    end
  end

  def eval(term, env) when is_atom(term) do
    Env.lookup(env, term)
  end

  def eval(term, _env) do
    term
  end
end
