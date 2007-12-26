%%%----------------------------------------------------------------------
%%% File    : mod_muc_admin.erl
%%% Author  : Badlop <badlop@ono.com>
%%% Purpose : Adds more commands to ejabberd_ctl
%%% Created : 8 Sep 2007 by Badlop <badlop@ono.com>
%%% Id      : $Id$
%%%----------------------------------------------------------------------

-module(mod_muc_admin).
-author('badlop@ono.com').

-behaviour(gen_mod).

-export([start/2,
	 stop/1,
	 web_menu_main/2, web_page_main/2,
	 web_menu_host/3, web_page_host/3,
	 ctl_process/2,
	 ctl_process/3
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

web_page_main(_, #request{path=["muc", "rooms"], lang = Lang} = _Request) ->
    Res = make_rooms_page(global, Lang),
    {stop, Res};

web_page_main(Acc, _) -> Acc.

web_page_host(_, Host,
	      #request{path = ["muc"],
		       lang = Lang} = _Request) ->
    Res = make_rooms_page(find_host(Host), Lang),
    {stop, Res};
web_page_host(Acc, _, _) -> Acc.

make_rooms_page(Host, Lang) ->
    Rooms1 = get_rooms(Host),
    Rooms2 = lists:ukeysort(1, Rooms1),
    Rooms3 = stringize_rooms(Rooms2),
    TList = lists:map(
	      fun(Room) ->
		      ?XE("tr", [?XC("td", E) || E <- Room])
	      end, Rooms3),
    Titles = ["Jabber ID",
	      "# participants",
	      "Last message",
	      "Public",
	      "Persistent",
	      "Logging",
	      "Just created",
	      "Title"],
    [?XC("h1", "Multi-User Chat"),
     ?XC("h2", "Rooms"),
     ?XE("table",
	 [?XE("thead",
	      [?XE("tr", [?XCT("td", Title) || Title <- Titles])
	      ]
	     ),
	  ?XE("tbody", TList)
	 ]
	)
    ].

stringize_rooms(Rooms) ->
    [stringize_room(Room) || Room <- Rooms].

stringize_room({Name, Host, Pid}) ->
    C = get_room_config(Pid),
    Title = C#config.title,
    Public = C#config.public,
    Persistent = C#config.persistent,
    Logging = C#config.logging,

    S = get_room_state(Pid),
    Just_created = S#state.just_created,
    Num_participants = length(dict:fetch_keys(S#state.users)),
    Last_message = "a long time ago", % TODO

    [Name++"@"++Host, 
     integer_to_list(Num_participants),
     Last_message,
     atom_to_list(Public),
     atom_to_list(Persistent), 
     atom_to_list(Logging), 
     atom_to_list(Just_created),
     Title].


%%----------------------------
%% MUC Destroy File
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
    ServerHost = lists:concat(ServerHostList),
    {Name, Host, ServerHost}.

destroy_room({N, H, SH}) ->
    io:format("Destroying room: ~s@~s - vhost: ~s~n", [N, H, SH]),
    mod_muc:room_destroyed(H, N, SH),
    mod_muc:forget_room(H, N).


%%----------------------------
%% MUC Unused
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
