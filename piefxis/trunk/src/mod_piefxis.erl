%%%----------------------------------------------------------------------
%%% File    : mod_piefxis.erl
%%% Author  : Badlop <badlop@process-one.net>
%%% Purpose : Add commands for XEP-0227 PIEFXIS
%%% Created : 
%%%----------------------------------------------------------------------

-module(mod_piefxis).

-behaviour(gen_mod).

-export([start/2,
	 stop/1,
	 ctl_process/2
	]).

-include("ejabberd.hrl").
-include("ejabberd_ctl.hrl").

%%-------------
%% gen_mod
%%-------------

start(_Host, _Opts) ->
    ejabberd_ctl:register_commands(commands_global(), ?MODULE, ctl_process).

stop(_Host) ->
    ejabberd_ctl:unregister_commands(commands_global(), ?MODULE, ctl_process).

commands_global() ->
    [
     {"import-piefxis file", "import users data from a PIEFXIS file (XEP-0227)"},
     {"export-piefxis dir", "export data of all users in the server to PIEFXIS files (XEP-0227)"},
     {"export-piefxis-host dir host", "export data of users in a host server to PIEFXIS files (XEP-0227)"}
    ].

%%-------------
%% Commands global
%%-------------

ctl_process(_Val, ["import-piefxis", File]) ->
    ejabberd_piefxis:import_file(File),
    ?STATUS_SUCCESS;
ctl_process(_Val, ["export-piefxis", Dir]) ->
    ejabberd_piefxis:export_server(Dir),
    ?STATUS_SUCCESS;
ctl_process(_Val, ["export-piefxis-host", Dir, Host]) ->
    ejabberd_piefxis:export_host(Dir, Host),
    ?STATUS_SUCCESS;

ctl_process(Val, _Args) ->
    Val.

