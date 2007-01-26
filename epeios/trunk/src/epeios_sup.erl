%%%-------------------------------------------------------------------
%%% File    : epeios_sup.erl
%%% Author  : Mickael Remond <mremond@process-one.net>
%%% Description : Main supervisor for the Epeios application.
%%% Created : 12 May 2006 by Mickael Remond <mremond@process-one.net>
%%%-------------------------------------------------------------------
-module(epeios_sup).
-author('mickael.remond@process-one.net').
-vsn('$Revision $ ').

-behaviour(supervisor).
-export([start_link/1,
	 get_module_pid/0,
	 stop_module/2]).

-export([init/1]).

-define(SERVER, ejabberd_sup).
-define(CHILDID, component).

%%--------------------------------------------------------------------
%% Function: start_link/1
%% Description: Starts the supervisor
%%--------------------------------------------------------------------
start_link(StartArgs) ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, StartArgs).
    

%%--------------------------------------------------------------------
%% Func: init/1
%% Returns: {ok,  {SupFlags,  [ChildSpec]}} |
%%          ignore                          |
%%          {error, Reason}   
%%--------------------------------------------------------------------
init([ComponentName, Server, Port, Secret, Module]) ->
    %% Start two childs:
    %% - the externalized ejabberd module
    %% - the xmpp_component manager
    ComponentSpec = {xmpp_component,
		     {xmpp_component, start_link,
		      [ComponentName, Server, Port, Secret, Module]},
		     permanent,5000,worker,[xmpp_component]},
    {ok, {{one_for_all,2,5}, [ComponentSpec]}}.

%% Return the PID of the ejabberd module
get_module_pid() ->
    Children = supervisor:which_children(?SERVER),
    case lists:keysearch(?CHILDID, 1, Children) of
	false  -> undefined;
	{value, {_Id,Child,_Type,_Modules}} -> Child
    end.

%% Stop the module 
stop_module(Module, ComponentName) ->
    Module:stop(xmpp_component:server_host(ComponentName)).
