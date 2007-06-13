%%%----------------------------------------------------------------------
%%% File    : mod_statsdx.erl
%%% Author  : Badlop
%%% Purpose : Calculates and gathers statistics actively
%%% Created :
%%% Id      : $Id$
%%%----------------------------------------------------------------------

-module(mod_statsdx).
-author('').
-vsn('$Revision$').

-behaviour(gen_mod).

-export([start/2, loop/0, stop/1, get_statistic/2, 
	remove_user/2, user_send_packet/3, user_receive_packet/4,
	user_login/1, user_logout/4]).

-include("ejabberd.hrl").
-include("jlib.hrl").
-include("mod_roster.hrl").

-define(PROCNAME, ejabberd_mod_statsdx).
-define(T(Text), translate:translate("Lang", Text)).

%% -------------------
%% Module control
%% -------------------

start(Host, Opts) ->
	Hooks = gen_mod:get_opt(hooks, Opts, true),
	% Default value for the counters
	CD = case Hooks of
		true -> 0;
		false -> "disabled"
	end,
	case whereis(?PROCNAME) of
		undefined ->
			application:start(os_mon),
			ets:new(stats, [named_table, public]),
			ets:insert(stats, {{user_login, server}, CD}),
			ets:insert(stats, {{user_logout, server}, CD}),
			ets:insert(stats, {{remove_user, server}, CD}),
			lists:foreach(
				fun(E) -> ets:insert(stats, {{client, server, E}, CD}) end,
				list_elem(clients, id)
			),
			lists:foreach(
				fun(E) -> ets:insert(stats, {{os, server, E}, CD}) end,
				list_elem(oss, id)
			),
			register(?PROCNAME, spawn(?MODULE, loop, []));
		_ ->
			ok
	end,
	ets:insert(stats, {{user_login, Host}, CD}),
	ets:insert(stats, {{user_logout, Host}, CD}),
	ets:insert(stats, {{remove_user, Host}, CD}),
	ets:insert(stats, {{send, Host, iq, in}, CD}),
	ets:insert(stats, {{send, Host, iq, out}, CD}),
	ets:insert(stats, {{send, Host, message, in}, CD}),
	ets:insert(stats, {{send, Host, message, out}, CD}),
	ets:insert(stats, {{send, Host, presence, in}, CD}),
	ets:insert(stats, {{send, Host, presence, out}, CD}),
	ets:insert(stats, {{recv, Host, iq, in}, CD}),
	ets:insert(stats, {{recv, Host, iq, out}, CD}),
	ets:insert(stats, {{recv, Host, message, in}, CD}),
	ets:insert(stats, {{recv, Host, message, out}, CD}),
	ets:insert(stats, {{recv, Host, presence, in}, CD}),
	ets:insert(stats, {{recv, Host, presence, out}, CD}),
	lists:foreach(
		fun(E) -> ets:insert(stats, {{client, Host, E}, CD}) end,
		list_elem(clients, id)
	),
	lists:foreach(
		fun(E) -> ets:insert(stats, {{os, Host, E}, CD}) end,
		list_elem(oss, id)
	),
	case Hooks of
		true ->
			ejabberd_hooks:add(user_send_packet, Host, ?MODULE, user_send_packet, 90),
			ejabberd_hooks:add(user_receive_packet, Host, ?MODULE, user_receive_packet, 90),
			ejabberd_hooks:add(remove_user, Host, ?MODULE, remove_user, 90),
			ejabberd_hooks:add(user_available_hook, Host, ?MODULE, user_login, 90),
			ejabberd_hooks:add(unset_presence_hook, Host, ?MODULE, user_logout, 90);
		false ->
			ok
	end.

loop() ->
	receive
		stop -> ok
	end.

stop(Host) ->
    ejabberd_hooks:delete(user_send_packet, Host, ?MODULE, user_send_packet, 60),
    ejabberd_hooks:delete(user_receive_packet, Host, ?MODULE, user_receive_packet, 60),
    ejabberd_hooks:delete(remove_user, Host, ?MODULE, remove_user, 60),
	ets:delete(stats),
	case whereis(?PROCNAME) of
		undefined -> ok;
		_ -> 
			?PROCNAME ! stop
	end.


remove_user(_User, Server) ->
	ets:update_counter(stats, {remove_user, Server}, 1),
	ets:update_counter(stats, {remove_user, server}, 1).

user_send_packet(FromJID, ToJID, NewEl) ->
	Host = FromJID#jid.lserver,
	HostTo = ToJID#jid.lserver,
	{xmlelement, Type, _, _} = NewEl,
	Type2 = case Type of
		"iq" -> iq;
		"message" -> message;
		"presence" -> presence
	end,
	Dest = case is_host(HostTo, Host) of
		true -> in;
		false -> out
	end,
	ets:update_counter(stats, {send, Host, Type2, Dest}, 1),

	% Registrarse para tramitar Host/mod_stats2file
	case list_to_atom(ToJID#jid.lresource) of
		?MODULE -> received_response(FromJID, ToJID, NewEl);
		_ -> ok
	end.

user_receive_packet(_JID, From, To, FixedPacket) ->
	HostFrom = From#jid.lserver,
	Host = To#jid.lserver,
	{xmlelement, Type, _, _} = FixedPacket,
	Type2 = case Type of
		"iq" -> iq;
		"message" -> message;
		"presence" -> presence
	end,
	Dest = case is_host(HostFrom, Host) of
		true -> in;
		false -> out
	end,
	ets:update_counter(stats, {recv, Host, Type2, Dest}, 1).


%% -------------------
%% get(*
%% -------------------

%gett(Arg) -> get(node(), [Arg, title]).
getl(Args) -> get(node(), [Args]).
getl(Args, Host) -> get(node(), [Args, Host]).

%get(_Node, ["", title]) -> "";

get_statistic(N, A) -> 
	case catch get(N, A) of
		{'EXIT', _} -> unknown;
		Res -> Res
	end.

get(global, A) -> get(node(), A);

get(_, [{"reductions", _}, title]) -> "Reductions (per minute)";
get(_, [{"reductions", I}]) -> calc_avg(element(2, statistics(reductions)), I); %+++

get(_, ["cpu_avg1", title]) -> "Average system load (1 min)";
get(N, ["cpu_avg1"]) -> rpc:call(N, cpu_sup, avg1, [])/256;
get(_, ["cpu_avg5", title]) -> "Average system load (5 min)";
get(N, ["cpu_avg5"]) -> rpc:call(N, cpu_sup, avg1, [])/256;
get(_, ["cpu_avg15", title]) -> "Average system load (15 min)";
get(N, ["cpu_avg15"]) -> rpc:call(N, cpu_sup, avg15, [])/256;
get(_, ["cpu_nprocs", title]) -> "Number of UNIX processes running on this machine";
get(N, ["cpu_nprocs"]) -> rpc:call(N, cpu_sup, nprocs, []);
get(_, ["cpu_util", title]) -> "CPU utilization";
get(N, ["cpu_util"]) -> rpc:call(N, cpu_sup, util, []);

get(_, [{"cpu_util_user", _}, title]) -> "CPU utilization - user";
get(_, [{"cpu_util_nice_user", _}, title]) -> "CPU utilization - nice_user";
get(_, [{"cpu_util_kernel", _}, title]) -> "CPU utilization - kernel";
get(_, [{"cpu_util_wait", _}, title]) -> "CPU utilization - wait";
get(_, [{"cpu_util_idle", _}, title]) -> "CPU utilization - idle";
get(_, [{"cpu_util_user", U}]) -> [{user, Us}, _, _] = element(2, U), Us;
get(_, [{"cpu_util_nice_user", U}]) -> [_, {nice_user, NU}, _] = element(2, U), NU;
get(_, [{"cpu_util_kernel", U}]) -> [_, _, {kernel, K}] = element(2, U), K;
get(_, [{"cpu_util_wait", U}]) -> 
	case element(3, U) of
		[{wait, W}, {idle, _}] -> W;  % Solaris
		[{idle, _}] -> 0
	end;
get(_, [{"cpu_util_idle", U}]) -> 
	case element(3, U) of
		[{wait, _}, {idle, I}] -> I;  % Solaris
		[{idle, I}] -> I
	end;

get(_, [{"client", Id}, title]) -> atom_to_list(Id);
get(_, [{"client", Id}, Host]) -> 
	case ets:lookup(stats, {client, Host, Id}) of
		[{_, C}] -> C;
		[] -> 0
	end;
get(_, ["client", title]) -> "Client";
get(N, ["client", Host]) ->
	lists:map(
		fun(Id) -> 
			[Id_string] = io_lib:format("~p", [Id]),
			{Id_string, get(N, [{"client", Id}, Host])}
		end,
		lists:usort(list_elem(clients, id))
	);

get(_, [{"os", Id}, title]) -> atom_to_list(Id);
get(_, [{"os", Id}, list]) -> lists:usort(list_elem(oss, Id));
get(_, [{"os", Id}, Host]) -> [{_, C}] = ets:lookup(stats, {os, Host, Id}), C;
get(_, ["os", title]) -> "Operating System";
get(N, ["os", Host]) -> 
	lists:map(
		fun(Id) ->
			[Id_string] = io_lib:format("~p", [Id]),
			{Id_string, get(N, [{"os", Id}, Host])}
		end,
		lists:usort(list_elem(oss, id))
	);

get(_, [{"memsup_system", _}, title]) -> "Memory physical (bytes)";
get(_, [{"memsup_system", M}]) -> [_, _, {system_total_memory, R}] = M, R;
get(_, [{"memsup_free", _}, title]) -> "Memory free (bytes)";
get(_, [{"memsup_free", M}]) -> [_, {free_memory, R}, _] = M, R;

get(_, [{"user_login", _}, title]) -> "Logins (per minute)";
get(_, [{"user_login", I}, Host]) -> get_stat({user_login, Host}, I);
get(_, [{"user_logout", _}, title]) -> "Logouts (per minute)";
get(_, [{"user_logout", I}, Host]) -> get_stat({user_logout, Host}, I);
get(_, [{"remove_user", _}, title]) -> "Accounts deleted (per minute)";
get(_, [{"remove_user", I}, Host]) -> get_stat({remove_user, Host}, I);
get(_, [{Table, Type, Dest, _}, title]) -> filename:flatten([Table, Type, Dest]);
get(_, [{Table, Type, Dest, I}, Host]) -> get_stat({Table, Host, Type, Dest}, I);

get(_, ["localtime", title]) -> "Local time";
get(N, ["localtime"]) ->
	localtime_to_string(rpc:call(N, erlang, localtime, []));

get(_, ["vhost", title]) -> "Virtual host";
get(_, ["vhost", Host]) -> Host;

get(_, ["totalerlproc", title]) -> "Total Erlang processes running";
get(N, ["totalerlproc"]) -> rpc:call(N, erlang, system_info, [process_count]);
get(_, ["operatingsystem", title]) -> "Operating System";
get(N, ["operatingsystem"]) -> {rpc:call(N, os, type, []), rpc:call(N, os, version, [])};
get(_, ["erlangmachine", title]) -> "Erlang machine";
get(N, ["erlangmachine"]) -> rpc:call(N, erlang, system_info, [system_version]);
get(_, ["erlangmachinetarget", title]) -> "Erlang machine target";
get(N, ["erlangmachinetarget"]) -> rpc:call(N, erlang, system_info, [system_architecture]);
get(_, ["maxprocallowed", title]) -> "Maximum processes allowed";
get(N, ["maxprocallowed"]) -> rpc:call(N, erlang, system_info, [process_limit]);
get(_, ["procqueue", title]) -> "Number of processes on the running queue";
get(N, ["procqueue"]) -> rpc:call(N, erlang, statistics, [run_queue]);
get(_, ["uptimehuman", title]) -> "Uptime";
get(N, ["uptimehuman"]) -> 
	io_lib:format("~w days ~w hours ~w minutes ~p seconds", ms_to_time(get(N, ["uptime"])));
get(_, ["lastrestart", title]) -> "Last restart";
get(N, ["lastrestart"]) -> 
	Now = calendar:datetime_to_gregorian_seconds(rpc:call(N, erlang, localtime, [])),
	UptimeMS = get(N, ["uptime"]),
	Last_restartS = trunc(Now - (UptimeMS/1000)),
	Last_restart = calendar:gregorian_seconds_to_datetime(Last_restartS),
	localtime_to_string(Last_restart);

get(_, ["plainusers", title]) -> "Plain users";
get(_, ["plainusers"]) -> {R, _, _} = get_connectiontype(), R;
get(_, ["tlsusers", title]) -> "TLS users";
get(_, ["tlsusers"]) -> {_, R, _} = get_connectiontype(), R;
get(_, ["sslusers", title]) -> "SSL users";
get(_, ["sslusers"]) -> {_, _, R} = get_connectiontype(), R;
get(_, ["registeredusers", title]) -> "Registered users";
get(N, ["registeredusers"]) -> rpc:call(N, mnesia, table_info, [passwd, size]);
get(_, ["registeredusers", Host]) -> length(ejabberd_auth:get_vh_registered_users(Host));
get(_, ["authusers", title]) -> "Authenticated users";
get(N, ["authusers"]) -> rpc:call(N, mnesia, table_info, [session, size]);
get(_, ["authusers", Host]) -> get_authusers(Host);
get(_, ["onlineusers", title]) -> "Online users";
get(N, ["onlineusers"]) -> rpc:call(N, mnesia, table_info, [presence, size]);
get(_, ["onlineusers", Host]) -> length(ejabberd_sm:get_vh_session_list(Host));
get(_, ["httppollusers", title]) -> "HTTP-Poll users (aprox)";
get(N, ["httppollusers"]) -> rpc:call(N, mnesia, table_info, [http_poll, size]);

get(_, ["s2sconnections", title]) -> "Outgoing S2S connections";
get(_, ["s2sconnections"]) -> length(get_S2SConns());
get(_, ["s2sconnections", Host]) -> get_s2sconnections(Host);
get(_, ["s2sservers", title]) -> "Outgoing S2S servers";
get(_, ["s2sservers"]) -> length(lists:usort([element(2, C) || C <- get_S2SConns()]));

get(_, ["offlinemsg", title]) -> "Offline messages";
get(N, ["offlinemsg"]) -> rpc:call(N, mnesia, table_info, [offline_msg, size]);
get(_, ["offlinemsg", Host]) -> get_offlinemsg(Host);
get(_, ["totalrosteritems", title]) -> "Total roster items";
get(N, ["totalrosteritems"]) -> rpc:call(N, mnesia, table_info, [roster, size]);
get(_, ["totalrosteritems", Host]) -> get_totalrosteritems(Host);

get(_, ["meanitemsinroster", title]) -> "Mean items in roster";
get(_, ["meanitemsinroster"]) -> get_meanitemsinroster();
get(_, ["meanitemsinroster", Host]) -> get_meanitemsinroster(Host);

get(_, ["totalmucrooms", title]) -> "Total MUC rooms";
get(_, ["totalmucrooms"]) -> ets:info(muc_online_room, size);
get(_, ["totalmucrooms", Host]) -> get_totalmucrooms(Host);
get(_, ["permmucrooms", title]) -> "Permanent MUC rooms";
get(N, ["permmucrooms"]) -> rpc:call(N, mnesia, table_info, [muc_room, size]);
get(_, ["permmucrooms", Host]) -> get_permmucrooms(Host);
get(_, ["regmucrooms", title]) -> "Users registered at MUC service";
get(N, ["regmucrooms"]) -> rpc:call(N, mnesia, table_info, [muc_registered, size]);
get(_, ["regmucrooms", Host]) -> get_regmucrooms(Host);
get(_, ["regpubsubnodes", title]) -> "Registered nodes at Pub/Sub";
get(N, ["regpubsubnodes"]) -> rpc:call(N, mnesia, table_info, [pubsub_node, size]);
get(_, ["vcards", title]) -> "Total vCards published";
get(N, ["vcards"]) -> rpc:call(N, mnesia, table_info, [vcard, size]);
get(_, ["vcards", Host]) -> get_vcards(Host);

%get(_, ["ircconns", title]) -> "IRC connections";
%get(_, ["ircconns"]) -> ets:info(irc_connection, size);
%get(_, ["ircconns", Host]) -> get_irccons(Host); % This seems to crash for some people
get(_, ["uptime", title]) -> "Uptime";
get(N, ["uptime"]) -> element(1, rpc:call(N, erlang, statistics, [wall_clock]));
get(_, ["cputime", title]) -> "CPU Time";
get(N, ["cputime"]) -> element(1, rpc:call(N, erlang, statistics, [runtime]));

get(_, ["languages", title]) -> "Languages";
get(_, ["languages", Server]) -> get_languages(Server);

get(_, ["client_os", title]) -> "Client/OS";
get(_, ["client_os", Server]) -> get_client_os(Server);

get(N, A) -> 
	io:format(" ----- node: '~p', A: '~p'~n", [N, A]),
	"666".

%% -------------------
%% get_*
%% -------------------

get_S2SConns() -> ejabberd_s2s:dirty_get_connections().

get_tls_drv() ->
	R = lists:filter(
		fun(P) -> 
			case erlang:port_info(P, name) of 
				{name, "tls_drv"} -> true; 
				_ -> false 
			end 
		end, erlang:ports()),
	length(R).

get_connections(Port) ->
	R = lists:filter(
		fun(P) -> 
			case inet:port(P) of 
				{ok, Port} -> true;
				_ -> false 
			end 
		end, erlang:ports()),
	length(R).

get_totalrosteritems(Host) ->
    F = fun() ->
		F2 = fun(R, {H, A}) ->
			{_LUser, LServer, _LJID} = R#roster.usj,
			A2 = case LServer of
				H -> A+1;
				_ -> A
			end,
			{H, A2}
		end,
		mnesia:foldl(F2, {Host, 0}, roster)
	end,
    {atomic, {Host, Res}} = mnesia:transaction(F),
	Res.

% Copied from ejabberd_sm.erl
-record(session, {sid, usr, us, priority}).

get_authusers(Host) ->
    F = fun() ->
		F2 = fun(R, {H, A}) ->
			{_LUser, LServer, _LResource} = R#session.usr,
			A2 = case LServer of
				H -> A+1;
				_ -> A
			end,
			{H, A2}
		end,
		mnesia:foldl(F2, {Host, 0}, session)
	end,
    {atomic, {Host, Res}} = mnesia:transaction(F),
	Res.

-record(offline_msg, {us, timestamp, expire, from, to, packet}).

get_offlinemsg(Host) ->
    F = fun() ->
		F2 = fun(R, {H, A}) ->
			{_LUser, LServer} = R#offline_msg.us,
			A2 = case LServer of
				H -> A+1;
				_ -> A
			end,
			{H, A2}
		end,
		mnesia:foldl(F2, {Host, 0}, offline_msg)
	end,
    {atomic, {Host, Res}} = mnesia:transaction(F),
	Res.

-record(vcard, {us, vcard}).

get_vcards(Host) ->
    F = fun() ->
		F2 = fun(R, {H, A}) ->
			{_LUser, LServer} = R#vcard.us,
			A2 = case LServer of
				H -> A+1;
				_ -> A
			end,
			{H, A2}
		end,
		mnesia:foldl(F2, {Host, 0}, vcard)
	end,
    {atomic, {Host, Res}} = mnesia:transaction(F),
	Res.

-record(s2s, {fromto, pid, key}).

get_s2sconnections(Host) ->
    F = fun() ->
		F2 = fun(R, {H, A}) ->
		    {MyServer, _Server} = R#s2s.fromto,
			A2 = case MyServer of
				H -> A+1;
				_ -> A
			end,
			{H, A2}
		end,
		mnesia:foldl(F2, {Host, 0}, s2s)
	end,
    {atomic, {Host, Res}} = mnesia:transaction(F),
	Res.

-record(irc_connection, {jid_server_host, pid}).

get_irccons(Host) ->
	F2 = fun(R, {H, A}) ->
		{From, _Server, _Host} = R#irc_connection.jid_server_host,
		A2 = case From#jid.lserver of
			H -> A+1;
			_ -> A
		end,
		{H, A2}
	end,
    {Host, Res} = ets:foldl(F2, {Host, 0}, irc_connection),
	Res.

is_host(Host, Subhost) ->
	Pos = string:len(Host)-string:len(Subhost)+1,
	case string:rstr(Host, Subhost) of
		Pos -> true;
		_ -> false
	end.

-record(muc_online_room, {name_host, pid}).

get_totalmucrooms(Host) ->
	F2 = fun(R, {H, A}) ->
		{_Name, MUCHost} = R#muc_online_room.name_host,
		A2 = case is_host(MUCHost, H) of
			true -> A+1;
			false -> A
		end,
		{H, A2}
	end,
    {Host, Res} = ets:foldl(F2, {Host, 0}, muc_online_room),
	Res.

-record(muc_room, {name_host, opts}).

get_permmucrooms(Host) ->
    F = fun() ->
		F2 = fun(R, {H, A}) ->
			{_Name, MUCHost} = R#muc_room.name_host,
			A2 = case is_host(MUCHost, H) of
				true -> A+1;
				false -> A
			end,
			{H, A2}
		end,
		mnesia:foldl(F2, {Host, 0}, muc_room)
	end,
    {atomic, {Host, Res}} = mnesia:transaction(F),
	Res.

-record(muc_registered, {us_host, nick}).

get_regmucrooms(Host) ->
    F = fun() ->
		F2 = fun(R, {H, A}) ->
			{_User, MUCHost} = R#muc_registered.us_host,
			A2 = case is_host(MUCHost, H) of
				true -> A+1;
				false -> A
			end,
			{H, A2}
		end,
		mnesia:foldl(F2, {Host, 0}, muc_registered)
	end,
    {atomic, {Host, Res}} = mnesia:transaction(F),
	Res.

get_stat(Stat, Ims) ->
	Res = ets:lookup(stats, Stat),
	ets:update_counter(stats, Stat, {2,1,0,0}),
	[{_, C}] = Res,
	calc_avg(C, Ims).
	%C.

calc_avg(Count, TimeMS) ->
	TimeMIN = TimeMS/(1000*60),
	Count/TimeMIN.

%% -------------------
%% utilities
%% -------------------

get_connectiontype() ->
	C2 = get_connections(5222) -1,
	C3 = get_connections(5223) -1,
	NUplain = C2 + C3 - get_tls_drv(),
	NUtls = C2 - NUplain,
	NUssl = C3,
	{NUplain, NUtls, NUssl}.

ms_to_time(T) ->
	DMS = 24*60*60*1000,
	HMS = 60*60*1000,
	MMS = 60*1000,
	SMS = 1000,
	D = trunc(T/DMS),
	H = trunc((T - (D*DMS)) / HMS),
	M = trunc((T - (D*DMS) - (H*HMS)) / MMS),
	S = trunc((T - (D*DMS) - (H*HMS) - (M*MMS)) / SMS),
	[D, H, M, S].


% Cuando un usuario conecta, pedirle iq:version a nombre de Host/mod_stats2file
user_login(U) ->
	User = U#jid.luser,
	Host = U#jid.lserver,
	Resource = U#jid.lresource,
	ets:update_counter(stats, {user_login, server}, 1),
	ets:update_counter(stats, {user_login, Host}, 1),
	request_iqversion(User, Host, Resource).

% cuando un usuario desconecta, buscar en la tabla su JID/USR y quitarlo
user_logout(User, Host, Resource, _Status) ->
	ets:update_counter(stats, {user_logout, server}, 1),
	ets:update_counter(stats, {user_logout, Host}, 1),

	JID = jlib:make_jid(User, Host, Resource),
	case ets:lookup(stats, {session, JID}) of
		[{_, Client_id, OS_id, Lang}] ->
			ets:delete(stats, {session, JID}),
			ets:update_counter(stats, {client, Host, Client_id}, -1),
			ets:update_counter(stats, {client, server, Client_id}, -1),
			ets:update_counter(stats, {os, Host, OS_id}, -1),
			ets:update_counter(stats, {os, server, OS_id}, -1),
			update_counter_create(stats, {client_os, Host, Client_id, OS_id}, -1),
			update_counter_create(stats, {client_os, server, Client_id, OS_id}, -1),
			update_counter_create(stats, {lang, Host, Lang}, -1),
			update_counter_create(stats, {lang, server, Lang}, -1);
		[] ->
			ok
	end.

request_iqversion(User, Host, Resource) ->
	From = jlib:make_jid("", Host, atom_to_list(?MODULE)),
	FromStr = jlib:jid_to_string(From),
	To = jlib:make_jid(User, Host, Resource),
	ToStr = jlib:jid_to_string(To),
	Packet = {xmlelement,"iq", 
		[{"from",FromStr}, {"to",ToStr}, {"type","get"}, {"xml:lang","es"}],
		[{xmlcdata,"\n"}, {xmlcdata,"  "}, {xmlelement, "query", [{"xmlns","jabber:iq:version"}], []}, {xmlcdata,"\n"}]},
	ejabberd_local:route(From, To, Packet). 

% cuando el virtualJID recibe una respuesta iqversion, 
% almacenar su JID/USR + client + OS en una tabla
received_response(From, _To, {xmlelement, "iq", Attrs, Elc}) ->
	User = From#jid.luser,
	Host = From#jid.lserver,
	Resource = From#jid.lresource,

    "result" = xml:get_attr_s("type", Attrs),
    Lang = case xml:get_attr_s("xml:lang", Attrs) of
		[] -> "unknown";
		L -> L
	end,
	update_counter_create(stats, {lang, Host, Lang}, 1),
	update_counter_create(stats, {lang, server, Lang}, 1),
	
	[El] = xml:remove_cdata(Elc),
	{xmlelement, _, Attrs2, _Els2} = El,
	?NS_VERSION = xml:get_attr_s("xmlns", Attrs2),

	Client = get_tag_cdata_subtag(El, "name"),
	%Version = get_tag_cdata_subtag(El, "version"),
	OS = get_tag_cdata_subtag(El, "os"),
	{Client_id, OS_id} = identify(Client, OS),

	ets:update_counter(stats, {client, Host, Client_id}, 1),
	ets:update_counter(stats, {client, server, Client_id}, 1),
	ets:update_counter(stats, {os, Host, OS_id}, 1),
	ets:update_counter(stats, {os, server, OS_id}, 1),
	update_counter_create(stats, {client_os, Host, Client_id, OS_id}, 1),
	update_counter_create(stats, {client_os, server, Client_id, OS_id}, 1),

	JID = jlib:make_jid(User, Host, Resource),
	ets:insert(stats, {{session, JID}, Client_id, OS_id, Lang}).

update_counter_create(Table, Element, C) ->
	case ets:lookup(Table, Element) of
		[] -> ets:insert(Table, {Element, 1});
		_ -> ets:update_counter(Table, Element, C)
	end.

get_tag_cdata_subtag(E, T) ->
	E2 = xml:get_subtag(E, T),
	case E2 of
		false -> "unknown";
		_ -> xml:get_tag_cdata(E2)
	end.

list_elem(Type, id) ->
	{_, Ids} = lists:unzip(list_elem(Type, full)),
	Ids;
list_elem(clients, full) ->
	[
		{"gaim", gaim},
		{"Gajim", gajim},
		{"Tkabber", tkabber},
		{"Psi", psi},
		{"Pandion", pandion},
		{"Kopete", kopete},
		{"Exodus", exodus},
		{"libgaim", libgaim},
		{"JBother", jbother},
		{"iChat", ichat},
		{"Miranda", miranda},
		{"Trillian", trillian},
		{"JAJC", jajc},
		{"Coccinella", coccinella},
		{"Gabber", gabber},
		{"BitlBee", bitlbee},
		{"jabber.el", jabberel},
		{"unknown", unknown}
	];
list_elem(oss, full) ->
	[
		{"Linux", linux}, 
		{"Win", windows}, 
		{"Gentoo", linux}, 
		{"Mac", mac}, 
		{"BSD", bsd}, 
		{"SunOS", linux}, 
		{"Ubuntu", linux},
		{"unknown", unknown}
	].

identify(Client, OS) ->
	Res = {try_match(Client, list_elem(clients, full)), try_match(OS, list_elem(oss, full))},
	case Res of
		{libgaim, mac} -> {adium, mac};
		_ -> Res
	end.

try_match(_E, []) -> unknown;
try_match(E, [{Str, Id} | L]) ->
	case string:str(E, Str) of
		0 -> try_match(E, L);
		_ -> Id
	end.

get_client_os(Server) ->
	CO1 = ets:match(stats, {{client_os, Server, '$1', '$2'}, '$3'}),
	CO2 = lists:map(
		fun([Cl, Os, A3]) -> 
			{lists:flatten([atom_to_list(Cl), "/", atom_to_list(Os)]), A3} 
		end,
		CO1
	),
	lists:keysort(1, CO2).

get_languages(Server) ->
	L1 = ets:match(stats, {{lang, Server, '$1'}, '$2'}),
	L2 = lists:map(
		fun([La, C]) -> 
			{La, C} 
		end,
		L1
	),
	lists:keysort(1, L2).

get_meanitemsinroster() ->
	get_meanitemsinroster2(getl("totalrosteritems"), getl("registeredusers")).
get_meanitemsinroster(Host) ->
	get_meanitemsinroster2(getl("totalrosteritems", Host), getl("registeredusers", Host)).
get_meanitemsinroster2(Items, Users) ->
	case Users of
		0 -> 0;
		_ -> Items/Users
	end.

localtime_to_string({{Y, Mo, D},{H, Mi, S}}) ->
	lists:concat([H, ":", Mi, ":", S, " ", D, "/", Mo, "/", Y]).

% cuando toque mostrar estadisticas
%get_iqversion() ->
	% contar en la tabla cuantos tienen cliente: *psi*
	%buscar en la tabla iqversion
	%ok.
