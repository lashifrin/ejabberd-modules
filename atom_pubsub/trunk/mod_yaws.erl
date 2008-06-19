%%%----------------------------------------------------------------------
%%% File    : mod_yaws.erl
%%% Author  : Badlop
%%% Purpose : Embed Yaws HTTP server into ejabberd
%%% Created : 
%%% Id      : $Id$
%%%----------------------------------------------------------------------
%%% Slightly modified, removing ymnesia
-module(mod_yaws).
-author('').
-vsn('0.2.1').

-behaviour(gen_mod).

-export([start/2, stop/1]).

-include("ejabberd.hrl").
-include("jlib.hrl").

-include("yaws.hrl"). %% File copied from yaws/includes/yaws.hrl
%-include("/usr/lib/yaws/yaws.hrl").

start(Host, Opts) ->
	% Get configuration options
	LogDir = gen_mod:get_opt(logdir, Opts, "www/log"),
	ServersDefault = {servers, [{Host, 8000, "www", []}]},
	Servers = gen_mod:get_opt(servers, Opts, ServersDefault),
	io:format(" servers: ~p~n", [Servers]),

	%YawsDir= gen_mod:get_opt(yawsdir, Opts, "/opt/var/yawsdir"),

	%% Start Yaws
	application:set_env(yaws, embedded, true),
	application:start(yaws),

	GC  = yaws_config:make_default_gconf(true, "Yaws http"),
	GC2 = GC#gconf{
       		logdir = LogDir
       	},

	RevproxyConf = [],

	SCs = lists:map(
		fun({Servername, Port, WWWDir, ServerOpts}) -> 
			IP = case get_opt(ip, ServerOpts) of
				[] -> {0, 0, 0, 0};
				[C] -> C
			end,
			Flag_dir_listing = case get_opt(dir_listing, ServerOpts) of
				[] -> ?SC_DEF;
				[false] -> ?SC_DEF;
				[true] -> ?SC_DIR_LISTINGS
			end,
			SSL = case get_opt(certfile, ServerOpts) of
				[] -> undefined;
				[Cert] -> #ssl{keyfile = Cert, certfile = Cert}
			end,
			AppMods = get_opt(appmods, ServerOpts),
			%case get_opt(appmods, ServerOpts) of
			%	[] -> [ymnesia];
			%	[A] ->[ymnesia, A]
			%end,
			Opaque = case get_opt(opaque, ServerOpts) of
				[] -> undefined;
				[O] ->O
			end,
			[#sconf{
				port = Port,
				servername = Servername,
				listen = IP,
				docroot = WWWDir,
				ssl = SSL,
				appmods = AppMods,
				allowed_scripts = [yaws],
				flags = Flag_dir_listing,
				revproxy = RevproxyConf,
				opaque = Opaque
			}]
		end, 
		Servers),

	yaws_api:setconf(GC2, SCs).

stop(_Host) ->
	application:stop(yaws).

get_opt(Opt, List) ->
	[ B || {A, B} <- List, A==Opt].
