-module(ejabberd).

-export([get_so_path/0]).

get_so_path() ->
    epeios_config:lib_path().
