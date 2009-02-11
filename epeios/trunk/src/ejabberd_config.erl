%%% File    : ejabberd_config.erl
%%% Author  : Mickael Remond <mremond@process-one.net>
%%% Description : Wrapper to access the container configuration
%%%               instead of ejabberd configuration
%%% Created : 11 May 2006 by Mickael Remond <mremond@process-one.net>
%%% Copyright 2006, ProcessOne

-module(ejabberd_config).

-export([start/0,
         get_global_option/1,
	 get_local_option/1]).

start() ->
    ok.

%% What to return when ask for Virtual host names
get_global_option(hosts) ->
    [epeios_config:server_host()];
get_global_option({shaper, _Name, _Host}) ->
    undefined;
get_global_option(Opt) ->
    get_option(Opt).

%% Ignore host: In the container we consider we have only one configuration
%% scheme.
get_local_option({Opt, _Host}) ->
    get_option(Opt).

get_option(Opt) ->
    Config = epeios_config:host_config(),
    case lists:keysearch(Opt, 1, Config) of
	{value, {Opt, Value}} ->
	    Value;
	_ -> ""
    end.
