%%%----------------------------------------------------------------------
%%% File    : mod_muc_admin.erl
%%% Author  : Badlop <badlop@ono.com>
%%% Purpose : Adds more commands to ejabberd_ctl
%%% Created : 8 Sep 2007 by Badlop <badlop@ono.com>
%%% Id      : $Id: mod_muc_admin.erl 344 2007-08-29 11:57:43Z badlop $
%%%----------------------------------------------------------------------

-module(mod_muc_admin).
-author('badlop@ono.com').
-vsn('$Revision: 344 $ ').

-behaviour(gen_mod).

-export([start/2,
	 stop/1,
	 ctl_process/2,
	 ctl_process/3
	]).

-include("ejabberd.hrl").
-include("ejabberd_ctl.hrl").
-include("jlib.hrl").

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
    register_commands(Host).

stop(Host) ->
    unregister_commands(Host).


%%----------------------------
%% ctl commands
%%----------------------------

commands_global() ->
    [
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

register_commands(Host) ->
    ejabberd_ctl:register_commands(commands_global(), ?MODULE, ctl_process),
    ejabberd_ctl:register_commands(Host, commands_host(), ?MODULE, ctl_process).

unregister_commands(Host) ->
    ejabberd_ctl:unregister_commands(commands_global(), ?MODULE, ctl_process),
    ejabberd_ctl:unregister_commands(Host, commands_host(), ?MODULE, ctl_process).

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
