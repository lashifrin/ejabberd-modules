%%%-------------------------------------------------------------------
%%% File    : epeios_services.erl
%%% Author  : Mickael Remond <mremond@process-one.net>
%%% Description : Component container services
%%%               Manage the services that are normally provided by
%%%               ejabberd.
%%% Created : 14 May 2006 by Mickael Remond <mremond@process-one.net>
%%%-------------------------------------------------------------------
-module(epeios_services).

-export([start/0,
	 stop/0]).

%% Component container code.
start() ->
    %% Dynamic loglevel
    ejabberd_loglevel:set(5),

    %% For handshake 
    %%crypto:start(),

    %% Random number generator
    %% (ejabberd wrapper)
    randoms:start(),

    %% Mnesia must be started and running
    mnesia_init(),

    %% Start translation service
    %% TODO: Provide a dummy translate module to avoid bundling the
    %% translation module for now.
    translate:start(),

    %% Start the module manager
    gen_mod:start(),

    %% Start the stringprep service
    stringprep:start(),

    %% Load the expat driver:   
    erl_ddll:load_driver(ejabberd:get_so_path(), expat_erl),
 
    %% Start configuration service
    %% We start a fake config service:
    ejabberd_config:start().    

%% Mnesia init:
%% ejabberd provide a database to the modules
%% the xmpp_component container does the same.
mnesia_init() ->
    %% Set database directory:
    application:load(mnesia),
    application:set_env(mnesia, dir, epeios_config:db_path()),

    %% Create schema:
    case mnesia:system_info(extra_db_nodes) of
        [] ->
            mnesia:create_schema([node()]);
        _ ->
            ok
    end,

    %% Start database:
    mnesia:start(),
    mnesia:wait_for_tables(mnesia:system_info(local_tables), infinity).

%% Stop the started services:
stop() ->
    mnesia:stop().
