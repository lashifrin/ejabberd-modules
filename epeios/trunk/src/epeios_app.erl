%%%-------------------------------------------------------------------
%%% File    : epeios_app.erl
%%% Author  : Mickael Remond <mremond@process-one.net>
%%% Description : Main epeios module
%%%
%%% Created : 12 May 2006 by Mickael Remond <mremond@process-one.net>
%%%-------------------------------------------------------------------
-module(epeios_app).
-author('mickael.remond@process-one.net').
-vsn('$Revision $ ').

-behaviour(application).
-export([start/2, stop/1]).

start(_Type, []) ->
    ComponentName = epeios_config:component_name(),
    ServerHost    = epeios_config:server_host(),
    ServerPort    = epeios_config:server_port(),
    Secret        = epeios_config:secret(),
    Module        = epeios_config:module(),

    epeios_services:start(),

    epeios_sup:start_link([ComponentName, ServerHost, ServerPort, Secret, Module]).

stop(_State) ->
    %% Module shutdown:
    ComponentName = epeios_config:component_name(),
    Module        = epeios_config:module(),
    epeios_sup:stop_module(Module,ComponentName),

    epeios_services:stop(),
    _State.
