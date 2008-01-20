%%%----------------------------------------------------------------------
%%% File    : mod_ctlextra.erl
%%% Author  : Badlop <badlop@ono.com>
%%% Purpose : Adds more commands to ejabberd_ctl
%%% Created : 30 Nov 2006 by Badlop <badlop@ono.com>
%%% Id      : $Id$
%%%----------------------------------------------------------------------

-module(mod_ctlextra).
-author('badlop@ono.com').

-behaviour(gen_mod).

-export([start/2,
	 stop/1,
	 ctl_process/2,
	 ctl_process/3
	]).

-include("ejabberd.hrl").
-include("ejabberd_ctl.hrl").
-include("jlib.hrl").
-include("mod_roster.hrl").

%% Copied from ejabberd_sm.erl
-record(session, {sid, usr, us, priority, info}).


%%-------------
%% gen_mod
%%-------------

start(Host, _Opts) ->
    ejabberd_ctl:register_commands(commands_global(), ?MODULE, ctl_process),
    ejabberd_ctl:register_commands(Host, commands_host(), ?MODULE, ctl_process).

stop(Host) ->
    ejabberd_ctl:unregister_commands(commands_global(), ?MODULE, ctl_process),
    ejabberd_ctl:unregister_commands(Host, commands_host(), ?MODULE, ctl_process).

commands_global() ->
    [
     {"compile file", "recompile and reload file"},
     {"load-config file", "load config from file"},
     {"remove-node nodename", "remove an ejabberd node from the database"},

     %% ejabberd_auth
     {"delete-older-users days", "delete users that have not logged in the last 'days'"},
     {"set-password user server password", "set password to user@server"},

     %% ejd2odbc
     {"export2odbc server output", "export Mnesia tables on server to files on output directory"},

     %% mod_offline
     {"delete-older-messages days", "delete offline messages older than 'days'"},

     %% mod_shared_roster
     {"srg-create group host name description display", "create the group with options"},
     {"srg-delete group host", "delete the group"},
     {"srg-user-add user server group host", "add user@server to group on host"},
     {"srg-user-del user server group host", "delete user@server from group on host"},

     %% mod_vcard
     {"vcard-get user host data [data2]", "get data from the vCard of the user"},
     {"vcard-set user host data [data2] content", "set data to content on the vCard"},

     %% mod_announce
     %% announce_send_online host message
     %% announce_send_all host, message

     %% mod_roster
     {"add-rosteritem user1 server1 user2 server2 nick group subs", "Add user2@server2 to user1@server1's roster"},
     %%{"", "subs= none, from, to or both"},
     %%{"", "example: add-roster peter localhost mike server.com MiKe Employees both"},
     %%{"", "will add mike@server.com to peter@localhost roster"},
     {"rem-rosteritem user1 server1 user2 server2", "Remove user2@server2 from user1@server1's roster"},
     {"pushroster file user server", "push template roster in file to user@server"},
     {"pushroster-all file", "push template roster in file to all those users"},
     {"push-alltoall server group", "adds all the users to all the users in Group"},

     {"status-list status", "list the logged users with status"},
     {"status-num status", "number of logged users with status"},

     {"stats registeredusers", "number of registered users"},
     {"stats onlineusers", "number of logged users"},
     {"stats uptime-seconds", "uptime of ejabberd node in seconds"},

     %% misc
     {"get-cookie", "get the Erlang cookie of this node"},
     {"killsession user server resource", "kill a user session"}
    ].

commands_host() ->
    [
     %% mod_last
     {"num-active-users days", "number of users active in the last 'days'"},
     {"status-list status", "list the logged users with status"},
     {"status-num status", "number of logged users with status"},
     {"stats registeredusers", "number of registered users"},
     {"stats onlineusers", "number of logged users"}
    ].


%%-------------
%% Commands global
%%-------------

ctl_process(_Val, ["blo"]) ->
    FResources = "eeeaaa aaa",
    io:format("~s", [FResources]),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["delete-older-messages", Days]) ->
    mod_offline:remove_old_messages(list_to_integer(Days)),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["delete-older-users", Days]) ->
    {removed, N, UR} = delete_older_users(list_to_integer(Days)),
    io:format("Deleted ~p users: ~p~n", [N, UR]),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["export2odbc", Server, Output]) ->
    Tables = [
	      {export_last, last},
	      {export_offline, offline},
	      {export_passwd, passwd},
	      {export_private_storage, private_storage},
	      {export_roster, roster},
	      {export_vcard, vcard},
	      {export_vcard_search, vcard_search}],
    Export = fun({TableFun, Table}) -> 
		     Filename = filename:join([Output, atom_to_list(Table)++".txt"]),
		     io:format("Trying to export Mnesia table '~p' on server '~s' to file '~s'~n", [Table, Server, Filename]),
		     catch ejd2odbc:TableFun(Server, Filename)
	     end,
    lists:foreach(Export, Tables),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["set-password", User, Server, Password]) ->
    ejabberd_auth:set_password(User, Server, Password),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["vcard-get", User, Server, Data]) ->
    {ok, Res} = vcard_get(User, Server, [Data]),
    io:format("~s~n", [Res]),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["vcard-get", User, Server, Data1, Data2]) ->
    {ok, Res} = vcard_get(User, Server, [Data1, Data2]),
    io:format("~s~n", [Res]),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["vcard-set", User, Server, Data1, Content]) ->
    {ok, Res} = vcard_set(User, Server, [Data1], Content),
    io:format("~s~n", [Res]),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["vcard-set", User, Server, Data1, Data2, Content]) ->
    {ok, Res} = vcard_set(User, Server, [Data1, Data2], Content),
    io:format("~s~n", [Res]),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["compile", Module]) ->
    compile:file(Module),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["remove-node", Node]) ->
    mnesia:del_table_copy(schema, list_to_atom(Node)),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["srg-create" | Parameters]) ->
	[Group, Host, Name, Description, Display] = group_parameters(Parameters, "'"),
    Opts = [{name, Name}, {displayed_groups, [Display]}, {description, Description}],
    {atomic, ok} = mod_shared_roster:create_group(Host, Group, Opts),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["srg-delete", Group, Host]) ->
    {atomic, ok} = mod_shared_roster:delete_group(Host, Group),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["srg-user-add", User, Server, Group, Host]) ->
    {atomic, ok} = mod_shared_roster:add_user_to_group(Host, {User, Server}, Group),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["srg-user-del", User, Server, Group, Host]) ->
    {atomic, ok} = mod_shared_roster:remove_user_from_group(Host, {User, Server}, Group),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["add-rosteritem", LocalUser, LocalServer, RemoteUser, RemoteServer, Nick, Group, Subs]) ->
    case add_rosteritem(LocalUser, LocalServer, RemoteUser, RemoteServer, Nick, Group, list_to_atom(Subs), []) of
	{atomic, ok} ->
	    ?STATUS_SUCCESS;
	{error, Reason} ->
	    io:format("Can't add ~p@~p to ~p@~p: ~p~n",
		      [RemoteUser, RemoteServer, LocalUser, LocalServer, Reason]),
	    ?STATUS_ERROR;
	{badrpc, Reason} ->
	    io:format("Can't add roster item to user ~p: ~p~n",
		      [LocalUser, Reason]),
	    ?STATUS_BADRPC
    end;

ctl_process(_Val, ["rem-rosteritem", LocalUser, LocalServer, RemoteUser, RemoteServer]) ->
    case rem_rosteritem(LocalUser, LocalServer, RemoteUser, RemoteServer) of
	{atomic, ok} ->
	    ?STATUS_SUCCESS;
	{error, Reason} ->
	    io:format("Can't remove ~p@~p to ~p@~p: ~p~n",
		      [RemoteUser, RemoteServer, LocalUser, LocalServer, Reason]),
	    ?STATUS_ERROR;
	{badrpc, Reason} ->
	    io:format("Can't remove roster item to user ~p: ~p~n",
		      [LocalUser, Reason]),
	    ?STATUS_BADRPC
    end;

ctl_process(_Val, ["pushroster", File, User, Server]) ->
    case pushroster(File, User, Server) of
	ok ->
	    ?STATUS_SUCCESS;
	{error, Reason} ->
	    io:format("Can't push roster ~p to ~p@~p: ~p~n",
		      [File, User, Server, Reason]),
	    ?STATUS_ERROR;
	{badrpc, Reason} ->
	    io:format("Can't push roster ~p: ~p~n",
		      [File, Reason]),
	    ?STATUS_BADRPC
    end;

ctl_process(_Val, ["pushroster-all", File]) ->
    case pushroster_all([File]) of
	ok ->
	    ?STATUS_SUCCESS;
	{error, Reason} ->
	    io:format("Can't push roster ~p: ~p~n",
		      [File, Reason]),
	    ?STATUS_ERROR;
	{badrpc, Reason} ->
	    io:format("Can't push roster ~p: ~p~n",
		      [File, Reason]),
	    ?STATUS_BADRPC
    end;

ctl_process(_Val, ["push-alltoall", Server, Group]) ->
    case push_alltoall(Server, Group) of
	ok ->
	    ?STATUS_SUCCESS;
	{error, Reason} ->
	    io:format("Can't push all to all: ~p~n",
		      [Reason]),
	    ?STATUS_ERROR;
	{badrpc, Reason} ->
	    io:format("Can't push all to all: ~p~n",
		      [Reason]),
	    ?STATUS_BADRPC
    end;

ctl_process(_Val, ["load-config", Path]) ->
    case ejabberd_config:load_file(Path) of
        {atomic, ok} ->
            ?STATUS_SUCCESS;
        {error, Reason} ->
            io:format("Can't load config file ~p: ~p~n",
                      [filename:absname(Path), Reason]),
	    ?STATUS_ERROR;
        {badrpc, Reason} ->
            io:format("Can't load config file ~p: ~p~n",
                      [filename:absname(Path), Reason]),
	    ?STATUS_BADRPC
    end;

ctl_process(_Val, ["stats", Stat]) ->
    Res = case Stat of
	      "uptime-seconds" -> uptime_seconds();
	      "registeredusers" -> mnesia:table_info(passwd, size);
	      "onlineusers" -> mnesia:table_info(session, size)
	  end,
    io:format("~p~n", [Res]),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["status-num", Status_required]) ->
    ctl_process(_Val, "all", ["status-num", Status_required]);

ctl_process(_Val, ["status-list", Status_required]) ->
    ctl_process(_Val, "all", ["status-list", Status_required]);

ctl_process(_Val, ["get-cookie"]) ->
    io:format("~s~n", [atom_to_list(erlang:get_cookie())]),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["killsession", User, Server, Resource]) ->
    ejabberd_router:route(
      jlib:make_jid("", "", ""), 
      jlib:make_jid(User, Server, Resource),
      {xmlelement, "broadcast", [], [{exit, "killed"}]}),
    ?STATUS_SUCCESS;

ctl_process(Val, _Args) ->
    Val.


%%-------------
%% Commands vhost
%%-------------

ctl_process(_Val, Host, ["num-active-users", Days]) ->
    Number = num_active_users(Host, list_to_integer(Days)),
    io:format("~p~n", [Number]),
    ?STATUS_SUCCESS;

ctl_process(_Val, Host, ["stats", Stat]) ->
    Res = case Stat of
	      "registeredusers" -> length(ejabberd_auth:get_vh_registered_users(Host));
	      "onlineusers" -> length(ejabberd_sm:get_vh_session_list(Host))
	  end,
    io:format("~p~n", [Res]),
    ?STATUS_SUCCESS;

ctl_process(_Val, Host, ["status-num", Status_required]) ->
    Num = length(get_status_list(Host, Status_required)),
    io:format("~p~n", [Num]),
    ?STATUS_SUCCESS;

ctl_process(_Val, Host, ["status-list", Status_required]) ->
    Res = get_status_list(Host, Status_required),
    [ io:format("~s@~s ~s ~p \"~s\"~n", [U, S, R, P, St]) || {U, S, R, P, St} <- Res],
    ?STATUS_SUCCESS;

ctl_process(Val, _Host, _Args) ->
    Val.


%%-------------
%% Utils
%%-------------

uptime_seconds() ->
    trunc(element(1, erlang:statistics(wall_clock))/1000).

get_status_list(Host, Status_required) ->
    %% Get list of all logged users
    Sessions = ejabberd_sm:dirty_get_my_sessions_list(),
    %% Reformat the list
    Sessions2 = [ {Session#session.usr, Session#session.sid, Session#session.priority} || Session <- Sessions],
    Fhost = case Host of
		"all" ->
		    %% All hosts are requested, so dont filter at all
		    fun(_, _) -> true end;
		_ ->
		    %% Filter the list, only Host is interesting
		    fun(A, B) -> A == B end
	    end,
    Sessions3 = [ {Pid, Server, Priority} || {{_User, Server, _Resource}, {_, Pid}, Priority} <- Sessions2, apply(Fhost, [Server, Host])],
    %% For each Pid, get its presence
    Sessions4 = [ {ejabberd_c2s:get_presence(Pid), Server, Priority} || {Pid, Server, Priority} <- Sessions3],
    %% Filter by status
    Fstatus = case Status_required of
		  "all" ->
		      fun(_, _) -> true end;
		  _ ->
		      fun(A, B) -> A == B end
	      end,
    [{User, Server, Resource, Priority, stringize(Status_text)} 
     || {{User, Resource, Status, Status_text}, Server, Priority} <- Sessions4, 
	apply(Fstatus, [Status, Status_required])].

%% Make string more print-friendly
stringize(String) ->
    %% Replace newline characters with other code
    element(2, regexp:gsub(String, "\n", "\\n")).

add_rosteritem(LU, LS, RU, RS, Nick, Group, Subscription, Xattrs) ->
    subscribe(LU, LS, RU, RS, Nick, Group, Subscription, Xattrs),
    route_rosteritem(LU, LS, RU, RS, Nick, Group, Subscription),
    {atomic, ok}.

subscribe(LocalUser, LocalServer, RemoteUser, RemoteServer, Nick, Group, Subscription, Xattrs) ->
    R = #roster{usj = {LocalUser,LocalServer,{RemoteUser,RemoteServer,[]}},
		us = {LocalUser,LocalServer},
		jid = {RemoteUser,RemoteServer,[]},
		name = Nick,
		subscription = Subscription, % none, to=you see him, from=he sees you, both
		ask = none, % out=send request, in=somebody requests you, none
		groups = [Group],
		askmessage = Xattrs, % example: [{"category","conference"}]
		xs = []},
    mnesia:transaction(fun() -> mnesia:write(R) end).

rem_rosteritem(LU, LS, RU, RS) ->
    unsubscribe(LU, LS, RU, RS),
    route_rosteritem(LU, LS, RU, RS, "", "", "remove"),
    {atomic, ok}.

unsubscribe(LocalUser, LocalServer, RemoteUser, RemoteServer) ->
    Key = {{LocalUser,LocalServer,{RemoteUser,RemoteServer,[]}},
	   {LocalUser,LocalServer}},
    mnesia:transaction(fun() -> mnesia:delete(roster, Key, write) end).

route_rosteritem(LocalUser, LocalServer, RemoteUser, RemoteServer, Nick, Group, Subscription) ->
    LJID = jlib:make_jid(LocalUser, LocalServer, ""),
    RJID = jlib:make_jid(RemoteUser, RemoteServer, ""),
    ToS = jlib:jid_to_string(LJID),
    ItemJIDS = jlib:jid_to_string(RJID),
    GroupXML = {xmlelement, "group", [], [{xmlcdata, Group}]},
    Item = {xmlelement, "item", 
	    [{"jid", ItemJIDS},
	     {"name", Nick},
	     {"subscription", Subscription}], 
	    [GroupXML]},
    Query = {xmlelement, "query", [{"xmlns", ?NS_ROSTER}], [Item]},
    Packet = {xmlelement, "iq", [{"type", "set"}, {"to", ToS}], [Query]},
    ejabberd_router:route(LJID, LJID, Packet).

pushroster(File, User, Server) ->
    {ok, [Roster]} = file:consult(File),
    subscribe_roster({User, Server, "", User}, Roster).

pushroster_all(File) ->
    {ok, [Roster]} = file:consult(File),
    subscribe_all(Roster).

subscribe_all(Roster) ->
    subscribe_all(Roster, Roster).
subscribe_all([], _) ->
    ok;
subscribe_all([User1 | Users], Roster) ->
    subscribe_roster(User1, Roster),
    subscribe_all(Users, Roster).

subscribe_roster(_, []) ->
    ok;
%% Do not subscribe a user to itself
subscribe_roster({Name, Server, Group, Nick}, [{Name, Server, _, _} | Roster]) ->
    subscribe_roster({Name, Server, Group, Nick}, Roster);
%% Subscribe Name2 to Name1
subscribe_roster({Name1, Server1, Group1, Nick1}, [{Name2, Server2, Group2, Nick2} | Roster]) ->
    subscribe(Name1, Server1, Name2, Server2, Nick2, Group2, both, []),
    subscribe_roster({Name1, Server1, Group1, Nick1}, Roster).

push_alltoall(S, G) ->
    Users = ejabberd_auth:get_vh_registered_users(S),
    Users2 = build_list_users(G, Users, []),
    subscribe_all(Users2).

build_list_users(_Group, [], Res) ->
    Res;
build_list_users(Group, [{User, Server}|Users], Res) ->
    build_list_users(Group, Users, [{User, Server, Group, User}|Res]).

vcard_get(User, Server, Data) ->
    [{_, Module, Function, _Opts}] = ets:lookup(sm_iqtable, {?NS_VCARD, Server}),
    JID = jlib:make_jid(User, Server, ""),
    IQ = #iq{type = get, xmlns = ?NS_VCARD},
    IQr = Module:Function(JID, JID, IQ),
    Res = case IQr#iq.sub_el of
	      [A1] ->
		  case vcard_get(Data, A1) of
		      false -> no_value;
		      Elem -> xml:get_tag_cdata(Elem)
		  end;
	      [] -> 
		  no_vcard
	  end,
    {ok, Res}.

vcard_get([Data1, Data2], A1) ->
    case xml:get_subtag(A1, Data1) of
    	false -> false;
	A2 -> vcard_get([Data2], A2)
    end;

vcard_get([Data], A1) ->
    xml:get_subtag(A1, Data).

vcard_set(User, Server, Data, Content) ->
    [{_, Module, Function, _Opts}] = ets:lookup(sm_iqtable, {?NS_VCARD, Server}),
    JID = jlib:make_jid(User, Server, ""),
    IQ = #iq{type = get, xmlns = ?NS_VCARD},
    IQr = Module:Function(JID, JID, IQ),

    %% Get old vcard
    A4 = case IQr#iq.sub_el of
	     [A1] ->
		 {_, _, _, A2} = A1,
		 update_vcard_els(Data, Content, A2);
	     [] -> 
		 update_vcard_els(Data, Content, [])
	 end,

    %% Build new vcard
    SubEl = {xmlelement, "vCard", [{"xmlns","vcard-temp"}], A4},
    IQ2 = #iq{type=set, sub_el = SubEl},

    Module:Function(JID, JID, IQ2),
    {ok, "done"}.

update_vcard_els(Data, Content, Els1) ->
    Els2 = lists:keysort(2, Els1),
    [Data1 | Data2] = Data,
    NewEl = case Data2 of
		[] ->
		    {xmlelement, Data1, [], [{xmlcdata,Content}]};
		[D2] ->
		    OldEl = case lists:keysearch(Data1, 2, Els2) of
				{value, A} -> A;
				false -> {xmlelement, Data1, [], []}
			    end,
		    {xmlelement, _, _, ContentOld1} = OldEl,
		    Content2 = [{xmlelement, D2, [], [{xmlcdata,Content}]}],
		    ContentOld2 = lists:keysort(2, ContentOld1),
		    ContentOld3 = lists:keydelete(D2, 2, ContentOld2),
		    ContentNew = lists:keymerge(2, Content2, ContentOld3),
		    {xmlelement, Data1, [], ContentNew}
	    end,
    Els3 = lists:keydelete(Data1, 2, Els2),
    lists:keymerge(2, [NewEl], Els3).

-record(last_activity, {us, timestamp, status}).

delete_older_users(Days) ->
    %% Convert older time
    SecOlder = Days*24*60*60,

    %% Get current time
    {MegaSecs, Secs, _MicroSecs} = now(),
    TimeStamp_now = MegaSecs * 1000000 + Secs,

    %% Get the list of registered users
    Users = ejabberd_auth:dirty_get_registered_users(),

    %% For a user, remove if required and answer true
    F = fun({LUser, LServer}) ->
		%% Check if the user is logged
		case ejabberd_sm:get_user_resources(LUser, LServer) of
		    %% If it isnt
		    [] ->
			%% Look for his last_activity
			case mnesia:dirty_read(last_activity, {LUser, LServer}) of
			    %% If it is
			    %% existent:
			    [#last_activity{timestamp = TimeStamp}] ->
				%% get his age
				Sec = TimeStamp_now - TimeStamp,
				%% If he is
				if 
				    %% younger than SecOlder: 
				    Sec < SecOlder ->
					%% do nothing
					false;
				    %% older: 
				    true ->
					%% remove the user
					ejabberd_auth:remove_user(LUser, LServer),
					true
				end;
			    %% nonexistent:
			    [] ->
				%% remove the user
				ejabberd_auth:remove_user(LUser, LServer),
				true
			end;
		    %% Else
		    _ ->
			%% do nothing
			false
		end
	end,
    %% Apply the function to every user in the list
    Users_removed = lists:filter(F, Users),
    {removed, length(Users_removed), Users_removed}.

num_active_users(Host, Days) ->
    list_last_activity(Host, true, Days).

%% Code based on ejabberd/src/web/ejabberd_web_admin.erl
list_last_activity(Host, Integral, Days) ->
    {MegaSecs, Secs, _MicroSecs} = now(),
    TimeStamp = MegaSecs * 1000000 + Secs,
    TS = TimeStamp - Days * 86400,
    case catch mnesia:dirty_select(
		 last_activity, [{{last_activity, {'_', Host}, '$1', '_'},
				  [{'>', '$1', TS}],
				  [{'trunc', {'/',
					      {'-', TimeStamp, '$1'},
					      86400}}]}]) of
							      {'EXIT', _Reason} ->
		 [];
	       Vals ->
		 Hist = histogram(Vals, Integral),
		 if
		     Hist == [] ->
			 0;
		     true ->
			 Left = if
				    Days == infinity ->
					0;
				    true ->
					Days - length(Hist)
				end,
			 Tail = if
				    Integral ->
					lists:duplicate(Left, lists:last(Hist));
				    true ->
					lists:duplicate(Left, 0)
				end,
			 lists:nth(Days, Hist ++ Tail)
		 end
	 end.
histogram(Values, Integral) ->
    histogram(lists:sort(Values), Integral, 0, 0, []).
histogram([H | T], Integral, Current, Count, Hist) when Current == H ->
    histogram(T, Integral, Current, Count + 1, Hist);
histogram([H | _] = Values, Integral, Current, Count, Hist) when Current < H ->
    if
	Integral ->
	    histogram(Values, Integral, Current + 1, Count, [Count | Hist]);
	true ->
	    histogram(Values, Integral, Current + 1, 0, [Count | Hist])
    end;
histogram([], _Integral, _Current, Count, Hist) ->
    if
	Count > 0 ->
	    lists:reverse([Count | Hist]);
	true ->
	    lists:reverse(Hist)
    end.

group_parameters(Ps, [Char]) ->
	{none, Grouped_Ps} = lists:foldl(
		fun(P, {State, Res}) ->
			case State of
				none -> 
					case P of
						[Char | PTail]->
							{building, [PTail | Res]};
						_ ->
							{none, [P | Res]}
					end;
				building -> 
					[ResHead | ResTail] = Res,
					case lists:last(P) of
						Char ->
							P2 = lists:sublist(P, length(P)-1),
							{none, [ResHead ++ " " ++ P2 | ResTail]};
						_ ->
							{building, [ResHead ++ " " ++ P | ResTail]}
					end
			end
		end,
		{none, []},
		Ps),
	lists:reverse(Grouped_Ps).
