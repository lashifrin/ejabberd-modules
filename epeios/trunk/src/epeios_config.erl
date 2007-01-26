%%%-------------------------------------------------------------------
%%% File    : epeios_config.erl
%%% Author  : Mickael Remond <mremond@process-one.net>
%%% Description : Wrapper to config option access
%%%
%%% Created : 12 May 2006 by Mickael Remond <mremond@process-one.net>
%%% Copyright 2006, Process-one
%%%-------------------------------------------------------------------
-module(epeios_config).
-author('mickael.remond@process-one.net').
-vsn('$Revision $ ').

-export([component_name/0,
	 server_host/0,
	 server_port/0,
	 secret/0,
	 module/0,
	 host_config/0,
	 db_path/0,
	 lib_path/0]).

%% TODO: Refactor

component_name() ->
    {ok, ComponentName} = application:get_env(epeios_name),
    ComponentName.

server_host() ->
    {ok, ServerHost} = application:get_env(epeios_server_host),
    ServerHost.

server_port() ->
    {ok, ServerPort} = application:get_env(epeios_server_port),
    ServerPort.
    
secret() ->
    {ok, Secret} = application:get_env(epeios_secret),
    Secret.

%% All module names are atom
module() ->
    {ok, Module} = application:get_env(epeios_module),
    list_to_atom(Module).

db_path() ->
    {ok, DbPath} = application:get_env(epeios_db_path),
    DbPath.

lib_path() ->
    {ok, LibPath} = application:get_env(epeios_lib_path),
    LibPath.

host_config() ->
    {ok, HostConfig} = application:get_env(epeios_host_config),
    HostConfig.
    
