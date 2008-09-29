%%%----------------------------------------------------------------------
%%% File    : mod_muc_admin.erl
%%% Author  : Badlop <badlop@ono.com>
%%% Purpose : Tools for additional MUC administration
%%% Created : 8 Sep 2007 by Badlop <badlop@ono.com>
%%% Id      : $Id: mod_muc_admin.erl 704 2008-08-01 19:24:13Z badlop $
%%%----------------------------------------------------------------------

-module(mod_muc_admin).
-author('badlop@ono.com').

-behaviour(gen_mod).

-export([
	 start/2, stop/1, % gen_mod API
	 create_room/3, destroy_room/3, % MUC Admin API
	 change_room_option/4,
	 set_affiliation/4,
	 web_menu_main/2, web_page_main/2, % Web Admin API
	 web_menu_host/3, web_page_host/3,
	 ctl_process/2, ctl_process/3 % ejabberdctl API
	]).

-include("ejabberd.hrl").
-include("ejabberd_ctl.hrl").
-include("jlib.hrl").
-include("ejabberd_http.hrl").
-include("ejabberd_web_admin.hrl").

%% Copied from mod_muc/mod_muc*.erl
-define(MAX_USERS_DEFAULT, 200).
-define(MAX_USERS_DEFAULT_LIST,
	[5, 10, 20, 30, 50, 100, 200, 500, 1000, 2000, 5000]).
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
		 max_users = ?MAX_USERS_DEFAULT,
		 logging = false
		}).
-record(state, {room,
		host,
		server_host,
		access,
		jid,
		config = #config{},
		users = ?DICT:new(),
		affiliations = ?DICT:new(),
		history,
		subject = "",
		subject_author = "",
		just_created = false,
		activity = ?DICT:new(),
		room_shaper,
		room_queue = queue:new()}).

%%----------------------------
%% gen_mod
%%----------------------------

start(Host, _Opts) ->
    ejabberd_hooks:add(webadmin_menu_main, ?MODULE, web_menu_main, 50),
    ejabberd_hooks:add(webadmin_menu_host, Host, ?MODULE, web_menu_host, 50),
    ejabberd_hooks:add(webadmin_page_main, ?MODULE, web_page_main, 50),
    ejabberd_hooks:add(webadmin_page_host, Host, ?MODULE, web_page_host, 50),
    ejabberd_ctl:register_commands(commands_global(), ?MODULE, ctl_process),
    ejabberd_ctl:register_commands(Host, commands_host(), ?MODULE, ctl_process).

stop(Host) ->
    ejabberd_hooks:delete(webadmin_menu_main, ?MODULE, web_menu_main, 50),
    ejabberd_hooks:delete(webadmin_menu_host, Host, ?MODULE, web_menu_host, 50),
    ejabberd_hooks:delete(webadmin_page_main, ?MODULE, web_page_main, 50),
    ejabberd_hooks:delete(webadmin_page_host, Host, ?MODULE, web_page_host, 50),
    ejabberd_hooks:delete(webadmin_user, Host, ?MODULE, web_user, 50),
    ejabberd_ctl:unregister_commands(commands_global(), ?MODULE, ctl_process),
    ejabberd_ctl:unregister_commands(Host, commands_host(), ?MODULE, ctl_process).


%%----------------------------
%% ctl commands
%%----------------------------

commands_global() ->
    [
     {"muc-unregister-nick nick", "unregister the nick in the muc service"},
     {"muc-create-file file", "create the rooms indicated in file"},
     {"muc-destroy-file file", "destroy the rooms whose JID is indicated in file"},
     {"muc-unused-list days", "list rooms without activity in last days"},
     {"muc-unused-destroy days", "destroy rooms without activity last days"},
     {"muc-online-rooms", "list existing rooms"}
    ].

commands_host() ->
    [
     {"muc-unused-list days", "list rooms without activity in last days"},
     {"muc-unused-destroy days", "destroy rooms without activity last days"},
     {"muc-online-rooms", "list existing rooms"}
    ].

ctl_process(_Val, ["muc-unregister-nick", Nick]) ->
    case muc_unregister_nick(Nick) of
	unregistered ->
	    ?STATUS_SUCCESS;
	{error, Error} ->
	    io:format("Error unregistering ~p: ~p~n", [Nick, Error]),
	    ?STATUS_ERROR
    end;

ctl_process(_Val, ["muc-create-file", Filename]) ->
    muc_create_file(Filename),
    io:format("Restart MUC or ejabberd for changes to take effect.~n"),
    ?STATUS_SUCCESS;

ctl_process(_Val, ["muc-destroy-file", Filename]) ->
    muc_destroy_file(Filename),
    ?STATUS_SUCCESS;

ctl_process(Val, ["muc-unused-list", Days]) ->
    ctl_process(Val, global, ["muc-unused-list", Days]);

ctl_process(Val, ["muc-unused-destroy", Days]) ->
    ctl_process(Val, global, ["muc-unused-destroy", Days]);

ctl_process(Val, ["muc-online-rooms"]) ->
    ctl_process(Val, global, ["muc-online-rooms"]);

ctl_process(Val, _Args) ->
    Val.


ctl_process(_Val, Host, ["muc-unused-list", Days]) ->
    {NA, NP, RP} = muc_unused(list, Host, list_to_integer(Days)),
    io:format("Unused rooms: ~p out of ~p~n", [NP, NA]),
    [io:format("~s@~s~n", [R, H]) || {R, H, _P} <- RP],
    ?STATUS_SUCCESS;

ctl_process(_Val, Host, ["muc-unused-destroy", Days]) ->
    {NA, NP, RP} = muc_unused(destroy, Host, list_to_integer(Days)),
    io:format("Destroyed unused rooms: ~p out of ~p~n", [NP, NA]),
    [io:format("~s@~s~n", [R, H]) || {R, H, _P} <- RP],
    ?STATUS_SUCCESS;

ctl_process(_Val, ServerHost, ["muc-online-rooms"]) ->
    MUCHost = find_host(ServerHost),
    format_print_room(MUCHost, ets:tab2list(muc_online_room)),
    ?STATUS_SUCCESS;

ctl_process(Val, _Host, _Args) ->
    Val.


%%----------------------------
%% Ad-hoc commands
%%----------------------------


%%----------------------------
%% Web Admin
%%----------------------------

%%---------------
%% Web Admin Menu

web_menu_main(Acc, Lang) ->
    Acc ++ [{"muc", ?T("Multi-User Chat")}].

web_menu_host(Acc, _Host, Lang) ->
    Acc ++ [{"muc", ?T("Multi-User Chat")}].


%%---------------
%% Web Admin Page

-define(TDTD(L, N),
	?XE("tr", [?XCT("td", L),
		   ?XC("td", integer_to_list(N))
		  ])).

web_page_main(_, #request{path=["muc"], lang = Lang} = _Request) ->
    Res = [?XC("h1", "Multi-User Chat"),
	   ?XC("h3", "Statistics"),
	   ?XAE("table", [],
		[?XE("tbody", [?TDTD("Total rooms", ets:info(muc_online_room, size)),
			       ?TDTD("Permanent rooms", mnesia:table_info(muc_room, size)),
			       ?TDTD("Registered nicknames", mnesia:table_info(muc_registered, size))
			      ])
		]),
	   ?XE("ul", [?LI([?ACT("rooms", "List of rooms")])])
	  ],
    {stop, Res};

web_page_main(_, #request{path=["muc", "rooms"], q = Q, lang = Lang} = _Request) ->
    Sort_query = get_sort_query(Q),
    Res = make_rooms_page(global, Lang, Sort_query),
    {stop, Res};

web_page_main(Acc, _) -> Acc.

web_page_host(_, Host,
	      #request{path = ["muc"],
		       q = Q,
		       lang = Lang} = _Request) ->
    Sort_query = get_sort_query(Q),
    Res = make_rooms_page(find_host(Host), Lang, Sort_query),
    {stop, Res};
web_page_host(Acc, _, _) -> Acc.


%% Returns: {normal | reverse, Integer}
get_sort_query(Q) ->
    case catch get_sort_query2(Q) of
	{ok, Res} -> Res;
	_ -> {normal, 1}
    end.

get_sort_query2(Q) ->
    {value, {_, String}} = lists:keysearch("sort", 1, Q),
    Integer = list_to_integer(String),
    case Integer >= 0 of
	true -> {ok, {normal, Integer}};
	false -> {ok, {reverse, abs(Integer)}}
    end.

make_rooms_page(Host, Lang, {Sort_direction, Sort_column}) ->
    Rooms_names = get_rooms(Host),
    Rooms_infos = build_info_rooms(Rooms_names),
    Rooms_sorted = sort_rooms(Sort_direction, Sort_column, Rooms_infos),
    Rooms_prepared = prepare_rooms_infos(Rooms_sorted),
    TList = lists:map(
	      fun(Room) ->
		      ?XE("tr", [?XC("td", E) || E <- Room])
	      end, Rooms_prepared),
    Titles = ["Jabber ID",
	      "# participants",
	      "Last message",
	      "Public",
	      "Persistent",
	      "Logging",
	      "Just created",
	      "Title"],
    {Titles_TR, _} =
	lists:mapfoldl(
	  fun(Title, Num_column) ->
		  NCS = integer_to_list(Num_column),
		  TD = ?XE("td", [?CT(Title),
				  ?C(" "),
				  ?ACT("?sort="++NCS, "<"),
				  ?C(" "),
				  ?ACT("?sort=-"++NCS, ">")]),
		  {TD, Num_column+1}
	  end,
	  1,
	  Titles),
    [?XC("h1", "Multi-User Chat"),
     ?XC("h2", "Rooms"),
     ?XE("table",
	 [?XE("thead",
	      [?XE("tr", Titles_TR)]
	     ),
	  ?XE("tbody", TList)
	 ]
	)
    ].

sort_rooms(Direction, Column, Rooms) ->
    Rooms2 = lists:keysort(Column, Rooms),
    case Direction of
	normal -> Rooms2;
	reverse -> lists:reverse(Rooms2)
    end.

build_info_rooms(Rooms) ->
    [build_info_room(Room) || Room <- Rooms].

build_info_room({Name, Host, Pid}) ->
    C = get_room_config(Pid),
    Title = C#config.title,
    Public = C#config.public,
    Persistent = C#config.persistent,
    Logging = C#config.logging,

    S = get_room_state(Pid),
    Just_created = S#state.just_created,
    Num_participants = length(dict:fetch_keys(S#state.users)),

    History = (S#state.history)#lqueue.queue,
    Ts_last_message =
	case queue:is_empty(History) of
	    true ->
		"A long time ago";
	    false ->
		Last_message1 = queue:last(History),
		{_, _, _, Ts_last, _} = Last_message1,
		jlib:timestamp_to_iso(Ts_last)
	end,

    {Name++"@"++Host,
     Num_participants,
     Ts_last_message,
     Public,
     Persistent,
     Logging,
     Just_created,
     Title}.

prepare_rooms_infos(Rooms) ->
    [prepare_room_info(Room) || Room <- Rooms].
prepare_room_info(Room_info) ->
    {NameHost,
     Num_participants,
     Ts_last_message,
     Public,
     Persistent,
     Logging,
     Just_created,
     Title} = Room_info,
    [NameHost,
     integer_to_list(Num_participants),
     Ts_last_message,
     atom_to_list(Public),
     atom_to_list(Persistent),
     atom_to_list(Logging),
     atom_to_list(Just_created),
     Title].


%%----------------------------
%% Create/Delete Room
%%----------------------------

%% @spec (Name::string(), Host::string(), ServerHost::string()) ->
%%       ok | {error, room_already_exists}
%% @doc Create a room immediately with the default options.
create_room(Name, Host, ServerHost) ->

    %% Get the default room options from the muc configuration
    DefRoomOpts = gen_mod:get_module_opt(ServerHost, mod_muc,
					 default_room_options, []),

    %% Store the room on the server, it is not started yet though at this point
    mod_muc:store_room(Host, Name, DefRoomOpts),

    %% Get all remaining mod_muc parameters that might be utilized
    Access = gen_mod:get_module_opt(ServerHost, mod_muc, access, all),
    AcCreate = gen_mod:get_module_opt(ServerHost, mod_muc, access_create, all),
    AcAdmin = gen_mod:get_module_opt(ServerHost, moc_muc, access_admin, none),
    AcPer = gen_mod:get_module_opt(ServerHost, mod_muc, access_persistent, all),
    HistorySize = gen_mod:get_module_opt(ServerHost, mod_muc, history_size, 20),
    RoomShaper = gen_mod:get_module_opt(ServerHost, mod_muc, room_shaper, none),

    %% If the room does not exist yet in the muc_online_room
    case mnesia:dirty_read(muc_online_room, {Name, Host}) of
        [] ->
	    %% Start the room
	    {ok, Pid} = mod_muc_room:start(
			  Host,
			  ServerHost,
			  {Access, AcCreate, AcAdmin, AcPer},
			  Name,
			  HistorySize,
			  RoomShaper,
			  DefRoomOpts),
	    {atomic, ok} = register_room(Host, Name, Pid),
	    ok;
	_ ->
	    {error, room_already_exists}
    end.

register_room(Host, Name, Pid) ->
    F = fun() ->
		mnesia:write(#muc_online_room{name_host = {Name, Host},
					      pid = Pid})
	end,
    mnesia:transaction(F).

%% Create the room only in the database.
%% It is required to restart the MUC service for the room to appear.
muc_create_room({Name, Host, _}, DefRoomOpts) ->
    io:format("Creating room ~s@~s~n", [Name, Host]),
    mod_muc:store_room(Host, Name, DefRoomOpts).

%% @spec (Name::string(), Host::string(), ServerHost::string()) ->
%%       ok | {error, room_not_exists}
%% @doc Destroy the room immediately.
destroy_room(Name, Host, ServerHost) ->
    case mnesia:dirty_read(muc_online_room, {Name, Host}) of
	[R] ->
	    Pid = R#muc_online_room.pid,
	    mod_muc:room_destroyed(Host, Name, Pid, ServerHost),
	    {atomic, ok} = mod_muc:forget_room(Host, Name),
	    ok;
	[] ->
	    {error, room_not_exists}
    end.

destroy_room({N, H, SH}) ->
    io:format("Destroying room: ~s@~s - vhost: ~s~n", [N, H, SH]),
    destroy_room(N, H, SH).


%%----------------------------
%% Destroy Rooms in File
%%----------------------------

%% The format of the file is: one chatroom JID per line
%% The file encoding must be UTF-8

muc_destroy_file(Filename) ->
    {ok, F} = file:open(Filename, [read]),
    RJID = read_room(F),
    Rooms = read_rooms(F, RJID, []),
    file:close(F),
    [destroy_room(A) || A <- Rooms].

read_rooms(_F, eof, L) ->
    L;

read_rooms(F, RJID, L) ->
    RJID2 = read_room(F),
    read_rooms(F, RJID2, [RJID | L]).

read_room(F) ->
    case io:get_line(F, "") of
	eof -> eof;
	String ->
	    case io_lib:fread("~s", String) of
		{ok, [RoomJID], _} -> split_roomjid(RoomJID);
		{error, What} ->
		    io:format("Parse error: what: ~p~non the line: ~p~n~n", [What, String])
	    end
    end.

%% This function is quite rudimentary
%% and may not be accurate
split_roomjid(RoomJID) ->
    [Name, Host] = string:tokens(RoomJID, "@"),
    [_MUC_service_name | ServerHostList] = string:tokens(Host, "."),
    ServerHost = join(ServerHostList, "."),
    {Name, Host, ServerHost}.

%% This function is copied from string:join/2 in Erlang/OTP R12B-1
%% Note that string:join/2 is not implemented in Erlang/OTP R11B
join([H|T], Sep) ->
    H ++ lists:concat([Sep ++ X || X <- T]).


%%----------------------------
%% Create Rooms in File
%%----------------------------

muc_create_file(Filename) ->
    {ok, F} = file:open(Filename, [read]),
    RJID = read_room(F),
    Rooms = read_rooms(F, RJID, []),
    file:close(F),
    %% Read the default room options defined for the first virtual host
    DefRoomOpts = gen_mod:get_module_opt(?MYNAME, mod_muc,
					 default_room_options, []),
    [muc_create_room(A, DefRoomOpts) || A <- Rooms].


%%----------------------------
%% List/Delete Unused Rooms
%%----------------------------

%%---------------
%% Control

muc_unused(Action, ServerHost, Days) ->
    Host = find_host(ServerHost),
    muc_unused2(Action, ServerHost, Host, Days).

muc_unused2(Action, ServerHost, Host, Last_allowed) ->
    %% Get all required info about all existing rooms
    Rooms_all = get_rooms(Host),

    %% Decide which ones pass the requirements
    Rooms_pass = decide_rooms(Rooms_all, Last_allowed),

    Num_rooms_all = length(Rooms_all),
    Num_rooms_pass = length(Rooms_pass),

    %% Perform the desired action for matching rooms
    act_on_rooms(Action, Rooms_pass, ServerHost),

    {Num_rooms_all, Num_rooms_pass, Rooms_pass}.

%%---------------
%% Get info

get_rooms(Host) ->
    Get_room_names = fun(Room_reg, Names) ->
			     Pid = Room_reg#muc_online_room.pid,
			     case {Host, Room_reg#muc_online_room.name_host} of
				 {Host, {Name1, Host}} -> 
				     [{Name1, Host, Pid} | Names];
				 {global, {Name1, Host1}} -> 
				     [{Name1, Host1, Pid} | Names];
				 _ ->
				     Names
			     end
		     end,
    ets:foldr(Get_room_names, [], muc_online_room).

get_room_config(Room_pid) ->
    {ok, R} = gen_fsm:sync_send_all_state_event(Room_pid, get_config),
    R.

get_room_state(Room_pid) ->
    {ok, R} = gen_fsm:sync_send_all_state_event(Room_pid, get_state),
    R.

%%---------------
%% Decide

decide_rooms(Rooms, Last_allowed) ->
    Decide = fun(R) -> decide_room(R, Last_allowed) end,
    lists:filter(Decide, Rooms).

decide_room({_Room_name, _Host, Room_pid}, Last_allowed) ->
    C = get_room_config(Room_pid),
    Persistent = C#config.persistent,

    S = get_room_state(Room_pid),
    Just_created = S#state.just_created,

    Room_users = S#state.users,
    Num_users = length(?DICT:to_list(Room_users)),

    History = (S#state.history)#lqueue.queue,
    Ts_now = calendar:now_to_universal_time(now()),
    Ts_uptime = uptime_seconds(),
    {Has_hist, Last} = case queue:is_empty(History) of
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

    case {Persistent, Just_created, Num_users, Has_hist, seconds_to_days(Last)} of
	{_true, false, 0, _, Last_days} 
	when Last_days >= Last_allowed -> 
	    true;
	_ ->
	    false
    end.

seconds_to_days(S) ->
    S div (60*60*24).

%%---------------
%% Act

act_on_rooms(Action, Rooms, ServerHost) ->
    ServerHosts = [ {A, find_host(A)} || A <- ?MYHOSTS ],
    Delete = fun({_N, H, _Pid} = Room) -> 
		     SH = case ServerHost of
			      global -> find_serverhost(H, ServerHosts);
			      O -> O
			  end,

		     act_on_room(Action, Room, SH)
	     end,
    lists:foreach(Delete, Rooms).

find_serverhost(Host, ServerHosts) ->
    {value, {ServerHost, Host}} = lists:keysearch(Host, 2, ServerHosts),
    ServerHost.

act_on_room(destroy, {N, H, Pid}, SH) ->
    mod_muc:room_destroyed(H, N, Pid, SH),
    mod_muc:forget_room(H, N);

act_on_room(list, _, _) ->
    ok.


%%----------------------------
%% Change Room Option
%%----------------------------

%% @spec(Name::string(), Service::string(), Option::string(), Value) -> ok
%%       Value = atom() | integer() | string()
%% @doc Change an option in an existing room.
%% Requires the name of the room, the MUC service where it exists,
%% the option to change (for example title or max_users),
%% and the value to assign to the new option.
%% For example:
%%   change_room_option("testroom", "conference.localhost", title, "Test Room")
change_room_option(Name, Service, Option, Value) ->
    Pid = get_room_pid(Name, Service),
    {ok, _} = change_room_option(Pid, Option, Value),
    ok.

change_room_option(Pid, Option, Value) ->
    Config = get_room_config(Pid),
    Config2 = change_option(Option, Value, Config),
    gen_fsm:sync_send_all_state_event(Pid, {change_config, Config2}).

%% @doc Get the Pid of an existing MUC room.
%% If the room doesn't exist, the function will crash.
get_room_pid(Name, Service) ->
    [Room] = mnesia:dirty_read(muc_online_room, {Name, Service}),
    Room#muc_online_room.pid.

%% It is required to put explicitely all the options because
%% the record elements are replaced at compile time.
%% So, this can't be parametrized.
change_option(Option, Value, Config) -> 
    case Option of
	allow_change_subj -> Config#config{allow_change_subj = Value};
	allow_private_messages -> Config#config{allow_private_messages = Value};
	allow_query_users -> Config#config{allow_query_users = Value};
	allow_user_invites -> Config#config{allow_user_invites = Value};
	anonymous -> Config#config{anonymous = Value};
	logging -> Config#config{logging = Value};
	max_users -> Config#config{max_users = Value};
	members_by_default -> Config#config{members_by_default = Value};
	members_only -> Config#config{members_only = Value};
	moderated -> Config#config{moderated = Value};
	password -> Config#config{password = Value};
	password_protected -> Config#config{password_protected = Value};
	persistent -> Config#config{persistent = Value};
	public -> Config#config{public = Value};
	public_list -> Config#config{public_list = Value};
	title -> Config#config{title = Value}
    end.


%%----------------------------
%% Unregister Nick
%%----------------------------

muc_unregister_nick(Nick) ->
    F2 = fun(N) -> 
		 [{_,Key,_}] = mnesia:index_read(muc_registered, N, 3), 
		 mnesia:delete({muc_registered, Key})
	 end,
    case mnesia:transaction(F2, [Nick], 1) of
	{atomic, ok} ->
	    unregistered;
	{aborted, Error} ->
	    {error, Error}
    end.

%%----------------------------
%% Change Room Affiliation
%%----------------------------

%% @spec(Name, Service, JID, Affiliation) -> ok | {error, Error}
%%       Name = string()
%%       Service = string()
%%       JID = string()
%%	 Affiliation = outcast, none, member, admin, owner
%% @doc Set the affiliation of JID in the room Name@Service.
%% If the affiliation is 'none', the action is to remove,
%% In any other case the action will be to create the affiliation.
set_affiliation(Name, Service, JID, Affiliation) ->
    case mnesia:dirty_read(muc_online_room, {Name, Service}) of
	[R] ->
	    %% Get the PID for the online room so we can get the state of the room
	    Pid = R#muc_online_room.pid,
	    {ok, StateData} = gen_fsm:sync_send_all_state_event(Pid, get_state),
	    SJID = jlib:string_to_jid(JID),
	    LJID = jlib:jid_remove_resource(jlib:jid_tolower(SJID)),
	    Affiliations = change_affiliation(Affiliation, LJID, StateData#state.affiliations),
	    Res = StateData#state{affiliations = Affiliations},
	    {ok, _State} = gen_fsm:sync_send_all_state_event(Pid, {change_state, Res}),
	    mod_muc:store_room(Res#state.host, Res#state.room, make_opts(Res)),
	    ok;
	[] ->
	    {error, room_not_exists}
    end.

change_affiliation(none, LJID, Affiliations) ->
    ?DICT:erase(LJID, Affiliations);
change_affiliation(Affiliation, LJID, Affiliations) ->
    ?DICT:store(LJID, Affiliation, Affiliations).

-define(MAKE_CONFIG_OPT(Opt), {Opt, Config#config.Opt}).

make_opts(StateData) ->
    Config = StateData#state.config,
    [
     ?MAKE_CONFIG_OPT(title),
     ?MAKE_CONFIG_OPT(allow_change_subj),
     ?MAKE_CONFIG_OPT(allow_query_users),
     ?MAKE_CONFIG_OPT(allow_private_messages),
     ?MAKE_CONFIG_OPT(public),
     ?MAKE_CONFIG_OPT(public_list),
     ?MAKE_CONFIG_OPT(persistent),
     ?MAKE_CONFIG_OPT(moderated),
     ?MAKE_CONFIG_OPT(members_by_default),
     ?MAKE_CONFIG_OPT(members_only),
     ?MAKE_CONFIG_OPT(allow_user_invites),
     ?MAKE_CONFIG_OPT(password_protected),
     ?MAKE_CONFIG_OPT(password),
     ?MAKE_CONFIG_OPT(anonymous),
     ?MAKE_CONFIG_OPT(logging),
     ?MAKE_CONFIG_OPT(max_users),
     {affiliations, ?DICT:to_list(StateData#state.affiliations)},
     {subject, StateData#state.subject},
     {subject_author, StateData#state.subject_author}
    ].


%%----------------------------
%% Utils
%%----------------------------

uptime_seconds() ->
    trunc(element(1, erlang:statistics(wall_clock))/1000).

find_host(global) ->
    global;
find_host(ServerHost) ->
    gen_mod:get_module_opt_host(ServerHost, mod_muc, "conference.@HOST@").

format_print_room(Host1, Rooms)->
    lists:foreach(
      fun({_, {Roomname, Host}, _}) ->
	      case Host1 of
		  global ->
		      io:format("~s@~s~n", [Roomname, Host]);
		  Host ->
		      io:format("~s@~s~n", [Roomname, Host]);
		  _ ->
		      ok
	      end
      end,
      Rooms).
