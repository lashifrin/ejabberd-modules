%%%----------------------------------------------------------------------
%%% File    : mod_ctlextra.erl
%%% Author  : Badlop
%%% Purpose : Adds more options for ejabberd_ctl
%%% Created :
%%% Id      : $Id$
%%%----------------------------------------------------------------------

-module(mod_ctlextra).
-author('').
-vsn('$Revision$').

-behaviour(gen_mod).

-export([
	start/2,
	stop/1,
	ctl_process/2,
	ctl_process/3
	]).

-include("ejabberd.hrl").
-include("ejabberd_ctl.hrl").
-include("jlib.hrl").

-record(session, {sid, usr, us, priority}). % copied from ejabberd_sm.erl

start(Host, _Opts) ->
	ejabberd_ctl:register_commands([
		{"compile file", "recompile and reload file"},
		{"load-config file", "load config from file"},
		{"remove-node nodename", "remove an ejabberd node from the database"},

		% ejabberd_auth
		{"delete-older-users days", "delete users that have not logged in the last 'days'"},
		{"set-password user server password", "set password to user@server"},

		% ejd2odbc
		{"export2odbc server output", "export Mnesia tables on server to files on output directory"},

		% mod_offline
		{"delete-older-messages days", "delete offline messages older than 'days'"},

		% mod_shared_roster
		{"srg-create group host name description display", "create the group with options"},
		{"srg-delete group host", "delete the group"},
		{"srg-user-add user server group host", "add user@server to group on host"},
		{"srg-user-del user server group host", "delete user@server from group on host"},
			
		% mod_vcard
		{"vcard-get user host data [data2]", "get data from the vCard of the user"},
		{"vcard-set user host data [data2] content", "set data to content on the vCard"},

		% mod_announce
		% announce_send_online host message
		% announce_send_all host, message

		% mod_muc
		% muc-add room opts
		% muc-del room
		{"muc-purge days", "destroy rooms with not activity on the last 'days'"},
		{"muc-online-rooms", "list existing rooms"},

		% mod_roster
		{"add-rosteritem user1 server1 user2 server2 nick group subs", "Add user2@server2 to user1@server1"},
		%{"", "subs= none, from, to or both"},
		%{"", "example: add-roster peter localhost mike server.com MiKe Employees both"},
		%{"", "will add mike@server.com to peter@localhost roster"},
		{"pushroster file user server", "push template roster in file to user@server"},
		{"pushroster-all file", "push template roster in file to all those users"},
		{"push-alltoall server group", "adds all the users to all the users in Group"},

		{"status-list status", "list the logged users with status"},
		{"status-num status", "number of logged users with status"},

		{"stats registeredusers", "number of registered users"},
		{"stats onlineusers", "number of logged users"},

		% misc
		{"get-cookie", "get the Erlang cookie of this node"},
		{"killsession user server resource", "kill a user session"}
	], ?MODULE, ctl_process),
    ejabberd_ctl:register_commands(Host, [
		% mod_muc
		{"muc-purge days", "destroy rooms with not activity on the last 'days'"},
		{"muc-online-rooms", "list existing rooms"},

		% mod_last
		{"num-active-users days", "number of users active in the last 'days'"},
		{"status-list status", "list the logged users with status"},
		{"status-num status", "number of logged users with status"},
		{"stats registeredusers", "number of registered users"},
		{"stats onlineusers", "number of logged users"}
	], ?MODULE, ctl_process),
	ok.

stop(_Host) ->
	ok.


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
	{ok, Res} = vcard_get(User, Server, {Data}),
    io:format("~s~n", [Res]),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["vcard-get", User, Server, Data1, Data2]) ->
	{ok, Res} = vcard_get(User, Server, {Data1, Data2}),
    io:format("~s~n", [Res]),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["vcard-set", User, Server, Data, Content]) ->
	{ok, Res} = vcard_set(User, Server, Data, Content),
    io:format("~s~n", [Res]),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["vcard-set", User, Server, Data1, Data2, Content]) ->
	{ok, Res} = vcard_set(User, Server, Data1, Data2, Content),
    io:format("~s~n", [Res]),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["compile", Module]) ->
    compile:file(Module),
	?STATUS_SUCCESS;

ctl_process(_Val, ["remove-node", Node]) ->
	mnesia:del_table_copy(schema, list_to_atom(Node)),
	?STATUS_SUCCESS;

ctl_process(_Val, ["srg-create", Group, Host, Name, Description, Display]) ->
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

ctl_process(_Val, ["muc-purge", Days]) ->
	{purged, Num_total, Num_purged, Names_purged} = muc_purge(list_to_integer(Days)),
	io:format("Purged ~p chatrooms from a total of ~p on the server:~n~p~n", [Num_purged, Num_total, Names_purged]),
	?STATUS_SUCCESS;

ctl_process(_Val, ["muc-online-rooms"]) ->
       format_print_room(all, ets:tab2list(muc_online_room)),
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


ctl_process(_Val, Host, ["muc-purge", Days]) ->
	{purged, Num_total, Num_purged, Names_purged} = muc_purge(Host, list_to_integer(Days)),
	io:format("Purged ~p chatrooms from a total of ~p on the host ~p:~n~p~n", [Num_purged, Num_total, Host, Names_purged]),
	?STATUS_SUCCESS;

ctl_process(_Val, ServerHost, ["muc-online-rooms"]) ->
	MUCHost = find_host(ServerHost),
	format_print_room(MUCHost, ets:tab2list(muc_online_room)),
	?STATUS_SUCCESS;

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
%% UTILS
%%-------------

get_status_list(Host, Status_required) ->
	% Get list of all logged users
	Sessions = ejabberd_sm:dirty_get_my_sessions_list(),
	% Reformat the list
	Sessions2 = [ {Session#session.usr, Session#session.sid, Session#session.priority} || Session <- Sessions],
	Fhost = case Host of
		"all" ->
			% All hosts are requested, so don't filter at all
			fun(_, _) -> true end;
		_ ->
			% Filter the list, only Host is interesting
			fun(A, B) -> A == B end
	end,
	Sessions3 = [ {Pid, Server, Priority} || {{_User, Server, _Resource}, {_, Pid}, Priority} <- Sessions2, apply(Fhost, [Server, Host])],
	% For each Pid, get its presence
	Sessions4 = [ {ejabberd_c2s:get_presence(Pid), Server, Priority} || {Pid, Server, Priority} <- Sessions3],
	% Filter by status
	Fstatus = case Status_required of
		"all" ->
			fun(_, _) -> true end;
		_ ->
			fun(A, B) -> A == B end
	end,
	[{User, Server, Resource, Priority, stringize(Status_text)} 
	 || {{User, Resource, Status, Status_text}, Server, Priority} <- Sessions4, 
	 apply(Fstatus, [Status, Status_required])].

% Make string more print-friendly
stringize(String) ->
	% Replace newline characters with other code
	element(2, regexp:gsub(String, "\n", "\\n")).

add_rosteritem(LU, LS, RU, RS, Nick, Group, Subscription, Xattrs) ->
	subscribe(LU, LS, RU, RS, Nick, Group, Subscription, Xattrs),
	% TODO: if the server is not local and Subs=to or both: send subscription request
	% TODO: check if the 'remote server' is a virtual host here, else do nothing
	%add_rosteritem2(RU, RS, LU, LS, LU, "", invert_subs(Subscription), Xattrs, Host).
	subscribe(RU, RS, LU, LS, LU, "", invert_subs(Subscription), Xattrs).

invert_subs(none) -> none;
invert_subs(to) -> none;
invert_subs(from) -> to;
invert_subs(both) -> both.

subscribe(LocalUser, LocalServer, RemoteUser, RemoteServer, Nick, Group, Subscription, Xattrs) ->
	mnesia:transaction(
		fun() ->
			mnesia:write({
				roster,
				{LocalUser,LocalServer,{RemoteUser,RemoteServer,[]}}, % usj
				{LocalUser,LocalServer},                 % us
				{RemoteUser,RemoteServer,[]},      % jid
				Nick,                  % name: "Mom", []
				Subscription,  % subscription: none, to=you see him, from=he sees you, both
				none,          % ask: out=send request, in=somebody requests you, none
				[Group],       % groups: ["Family"]
				Xattrs,        % xattrs: [{"category","conference"}]
				[]             % xs: []
		})
	end).

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
% Do not subscribe a user to itself
subscribe_roster({Name, Server, Group, Nick}, [{Name, Server, _, _} | Roster]) ->
	subscribe_roster({Name, Server, Group, Nick}, Roster);
% Subscribe Name2 to Name1
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

vcard_get(User, Server, DataX) ->
    [{_, _, A1}] = mnesia:dirty_read(vcard, {User, Server}),
    Elem = vcard_get(DataX, A1),
    {ok, xml:get_tag_cdata(Elem)}.

vcard_get({Data1, Data2}, A1) ->
    A2 = xml:get_subtag(A1, Data1),
    A3 = xml:get_subtag(A2, Data2),
    case A3 of
		"" -> A2;
		_ -> A3
	end;

vcard_get({Data}, A1) ->
    xml:get_subtag(A1, Data).

vcard_set(User, Server, Data1, Data2, Content) ->
	Content2 = {xmlelement, Data2, [], [{xmlcdata,Content}]},
	R = {xmlelement, Data1, [], [Content2]},
	vcard_set2(User, Server, R, Data1).

vcard_set(User, Server, Data, Content) ->
	R = {xmlelement, Data, [], [{xmlcdata,Content}]},
	vcard_set2(User, Server, R, Data).

vcard_set2(User, Server, R, Data) ->
	% Get old vcard
	A4 = case mnesia:dirty_read(vcard, {User, Server}) of
		[] -> 
			[R];
		[{_, _, A1}] ->
			{_, _, _, A2} = A1,
			A3 = lists:keydelete(Data, 2, A2),
			[R | A3]
	end,

	% Build new vcard
	SubEl = {xmlelement, "vCard", [{"xmlns","vcard-temp"}], A4},
	IQ = #iq{type=set, sub_el = SubEl},
	JID = jlib:make_jid(User, Server, ""),

	mod_vcard:process_sm_iq(JID, JID, IQ),
	{ok, "done"}.


-record(last_activity, {us, timestamp, status}).

delete_older_users(Days) ->
	% Convert older time
	SecOlder = Days*24*60*60,

	% Get current time
	{MegaSecs, Secs, _MicroSecs} = now(),
	TimeStamp_now = MegaSecs * 1000000 + Secs,

	% Get the list of registered users
	Users = ejabberd_auth:dirty_get_registered_users(),

	% For a user, remove if required and answer true
	F = fun({LUser, LServer}) ->
		% Check if the user is logged
		case ejabberd_sm:get_user_resources(LUser, LServer) of
			% If it isn't
			[] ->
				% Look for his last_activity
				case mnesia:dirty_read(last_activity, {LUser, LServer}) of
				% If it is
					% existent:
					[#last_activity{timestamp = TimeStamp}] ->
						% get his age
						Sec = TimeStamp_now - TimeStamp,
						% If he is
						if 
							% younger than SecOlder: 
							Sec < SecOlder ->
								% do nothing
								false;
							% older: 
							true ->
								% remove the user
								ejabberd_auth:remove_user(LUser, LServer),
								true
						end;
					% nonexistent:
					[] ->
						% remove the user
						ejabberd_auth:remove_user(LUser, LServer),
						true
				end;
			% Else
			_ ->
				% do nothing
				false
		end
	end,
	% Apply the function to every user in the list
	Users_removed = lists:filter(F, Users),
	{removed, length(Users_removed), Users_removed}.

num_active_users(Host, Days) ->
	list_last_activity(Host, true, Days).

% Code based on ejabberd/src/web/ejabberd_web_admin.erl
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


format_print_room(Host1, Rooms)->
	lists:foreach(
		fun({_, {Roomname, Host},_}) ->
			case Host1 of
				all ->
					io:format("~s ~s ~n", [Roomname, Host]);
				Host ->
					io:format("~s ~s ~n", [Roomname, Host]);
				_ ->
					ok
			end
		end,
		Rooms).


%%----------------------------
%% Purge MUC
%%----------------------------

% Required for muc_purge
% Copied from mod_muc/mod_muc_room.erl
-define(DICT, dict).
-record(muc_online_room, {name_host, pid}).
-record(lqueue, {queue, len, max}).
-record(config, {title = "",
		 allow_change_subj = true,
		 allow_query_users = true,
		 allow_private_messages = true,
		 public = true,
		 public_list = true,
		 persistent = false,
		 moderated = false, % TODO
		 members_by_default = true,
		 members_only = false,
		 allow_user_invites = false,
		 password_protected = false,
		 password = "",
		 anonymous = true,
		 logging = false
		}).
-record(state, {room,
		host,
		server_host,
		access,
		jid,
		config = #config{},
		users,
		affiliations,
		history,
		subject = "",
		subject_author = "",
		just_created = false}).

muc_purge(Days) ->
	ServerHost = global,
	Host = global,
	muc_purge2(ServerHost, Host, Days).

muc_purge(ServerHost, Days) ->
	Host = find_host(ServerHost),
	muc_purge2(ServerHost, Host, Days).

muc_purge2(ServerHost, Host, Last_allowed) ->
	Room_names = get_room_names(Host),

	Decide = fun(N) -> decide(N, Last_allowed) end,
	Rooms_to_delete = lists:filter(Decide, Room_names),

	Num_rooms = length(Room_names),
	Num_rooms_to_delete = length(Rooms_to_delete),

	Rooms_to_delete_full = fill_serverhost(Rooms_to_delete, ServerHost),

	Delete = fun({N, H, SH}) -> 
		mod_muc:room_destroyed(H, N, SH),
		mod_muc:forget_room(H, N)
	end,
	lists:foreach(Delete, Rooms_to_delete_full),
	{purged, Num_rooms, Num_rooms_to_delete, Rooms_to_delete}.

fill_serverhost(Rooms_to_delete, global) ->
	ServerHosts1 = ?MYHOSTS,
	ServerHosts2 = [ {ServerHost, find_host(ServerHost)} || ServerHost <- ServerHosts1],
	[ {Name, Host, find_serverhost(Host, ServerHosts2)} || {Name, Host} <- Rooms_to_delete];
fill_serverhost(Rooms_to_delete, ServerHost) ->
	[ {Name, Host, ServerHost}|| {Name, Host} <- Rooms_to_delete].

find_serverhost(Host, ServerHosts) ->
	{value, {ServerHost, Host}} = lists:keysearch(Host, 2, ServerHosts),
	ServerHost.

find_host(ServerHost) ->
	gen_mod:get_module_opt(ServerHost, mod_muc, host, "conference." ++ ServerHost).

decide({Room_name, Host}, Last_allowed) ->
	Room_pid = get_room_pid(Room_name, Host),

	C = get_room_config(Room_pid),
	Persistent = C#config.persistent,

	S = get_room_state(Room_pid),
	Just_created = S#state.just_created,

	Room_users = S#state.users,
	Num_users = length(?DICT:to_list(Room_users)),

	History = (S#state.history)#lqueue.queue,
	Ts_now = calendar:now_to_universal_time(now()),
	Ts_uptime = element(1, erlang:statistics(wall_clock))/1000,
	{Have_history, Last} = case queue:is_empty(History) of
		true ->
			{false, Ts_uptime};
		false ->
			Last_message = queue:last(History),
			{_, _, _, Ts_last, _} = Last_message,
			Ts_diff =
				calendar:datetime_to_gregorian_seconds(Ts_now)
				- calendar:datetime_to_gregorian_seconds(Ts_last),
			{true, Ts_diff}
	end,

	case {Persistent, Just_created, Num_users, Have_history, seconds_to_days(Last)} of
		{true, false, 0, _, Last_days} 
		when Last_days > Last_allowed -> 
			true;
		_ ->
			false
	end.

seconds_to_days(S) ->
	round(S) div 60*60*24.

get_room_names(Host) ->
	Get_room_names = fun(Room_reg, Names) ->
		case {Host, Room_reg#muc_online_room.name_host} of
			{Host, {Name1, Host}} -> 
				[{Name1, Host} | Names];
			{global, {Name1, Host1}} -> 
				[{Name1, Host1} | Names];
			_ ->
				Names
		end
	end,
	ets:foldr(Get_room_names, [], muc_online_room).

get_room_pid(Name, Host) ->
	[Room_ets] = ets:lookup(muc_online_room, {Name, Host}),
	Room_ets#muc_online_room.pid.

get_room_config(Room_pid) ->
	gen_fsm:sync_send_all_state_event(Room_pid, get_config).

get_room_state(Room_pid) ->
	gen_fsm:sync_send_all_state_event(Room_pid, get_state).
