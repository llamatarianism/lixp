alias Lisp.Env
alias Lisp.Reader
alias Lisp.BuiltIns

{:ok, pid} = Env.start_link(BuiltIns.std_env)

Reader.read_input pid
