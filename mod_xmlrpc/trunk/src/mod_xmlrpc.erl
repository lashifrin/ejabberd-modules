%%%----------------------------------------------------------------------
%%% File    : mod_xmlrpc.erl
%%% Author  : Badlop <badlop@ono.com>
%%% Purpose : XML-RPC server
%%% Created : 21 Aug 2007 by Badlop <badlop@ono.com>
%%% Id      : $Id$
%%%----------------------------------------------------------------------

-module(mod_xmlrpc).
-author('badlop@ono.com').

-behaviour(gen_mod).

-export([start/2,
	 handler/2,
	 loop/1,
	 stop/1]).

-include("ejabberd.hrl").
-define(PROCNAME, ejabberd_mod_xmlrpc).


%% -----------------------------
%% Module interface
%% -----------------------------

start(_Host, Opts) -> 
    case whereis(?PROCNAME) of
	undefined ->
	    %% get options
	    Port = gen_mod:get_opt(port, Opts, 4560),
	    MaxSessions = 10,
	    Timeout = 50,
	    Handler = {mod_xmlrpc, handler},
	    State = started,

	    Ip = gen_mod:get_opt(ip, Opts, all),

	    %% start the XML-RPC server
	    {ok, Pid} = xmlrpc:start_link(Ip, Port, MaxSessions, Timeout, Handler, State),

	    %% start the loop process
	    register(?PROCNAME, spawn(?MODULE, loop, [Pid]));
	_ ->
	    ok
    end.

loop(Pid) ->
    receive
        stop ->
	    xmlrpc:stop(Pid)
    end.

stop(_Host) ->
    ?PROCNAME ! stop.


%% -----------------------------
%% Handlers
%% -----------------------------

%% Call:           Arguments:                                      Returns:

%% .............................
%%  Debug

%% echothis        String                                          String
handler(_State, {call, echothis, [A]}) ->
    {false, {response, [A]}};

%% multhis         struct[{a, Integer}, {b, Integer}]              Integer
handler(_State, {call, multhis, [{struct, [{a, A}, {b, B}]}]}) ->
    {false, {response, [A*B]}};

%% .............................
%%  Statistics

%% tellme_title    String                                          String
handler(_State, {call, tellme_title, [A]}) ->
    {false, {response, [get_title(A)]}};

%% tellme_value    String                                          String
handler(_State, {call, tellme_value, [A]}) ->
    N = node(),
    {false, {response, [get_value(N, A)]}};

%% tellme          String          struct[{title, String}, {value. String}]
handler(_State, {call, tellme, [A]}) ->
    N = node(),
    T = {title, get_title(A)},
    V = {value, get_value(N, A)},
    R = {struct, [T, V]},
    {false, {response, [R]}};

%% .............................
%%  User administration

%% create_account  struct[{user, String}, {host, String}, {password, String}]      Integer
handler(_State, {call, create_account, [{struct, AttrL}]}) ->
    [U, H, P] = get_attrs([user, host, password], AttrL),
    R = case jlib:nodeprep(U) of
	    error ->
		error;
	    "" ->
		error;
	    _ ->
		ejabberd_auth:try_register(U, H, P)
	end,
    case R of
	{atomic, ok} ->
	    {false, {response, [0]}};
	{atomic, exists} ->
	    {false, {response, [409]}};
	_E ->
	    {false, {response, [1]}}
    end;

%% change_password struct[{user, String}, {host, String}, {newpass, String}]       Integer
handler(_State, {call, change_password, [{struct, AttrL}]}) ->
    [U, H, P] = get_attrs([user, host, newpass], AttrL),
    case ejabberd_auth:set_password(U, H, P) of
	{atomic, ok} ->
	    {false, {response, [0]}};
	_ ->
	    {false, {response, [1]}}
    end;

%% num_resources struct[{user, String}, {host, String}]                            Integer
handler(_State, {call, num_resources, [{struct, AttrL}]}) ->
    [U, H] = get_attrs([user, host], AttrL),
    R = length(ejabberd_sm:get_user_resources(U, H)),
    {false, {response, [R]}};

%% resource_num struct[{user, String}, {host, String}, {num, Integer}]             String
handler(_State, {call, resource_num, [{struct, AttrL}]}) ->
    [U, H, N] = get_attrs([user, host, num], AttrL),
    Resources = ejabberd_sm:get_user_resources(U, H),
    case (0<N) and (N=<length(Resources)) of
	true -> 
	    R = lists:nth(N, Resources),
	    {false, {response, [R]}};
	false ->
	    FaultString = lists:flatten(io_lib:format("Wrong resource number: ~p", [N])),
	    {false, {response, {fault, -1, FaultString}}}
    end;

%%% set_nickname    struct[{user, String}, {host, String}, {nickname, String}]      Integer
handler(_State, {call, set_nickname, [{struct, AttrL}]}) ->
    [U, H, N] = get_attrs([user, host, nickname], AttrL),
    R = mod_vcard:process_sm_iq(
	  {jid, U, H, "", U, H, ""},
	  {jid, U, H, "", U, H, ""},
	  {iq, "", set, "", "en", 
	   {xmlelement, "vCard", 
	    [{"xmlns", "vcard-temp"}], [
					{xmlelement, "NICKNAME", [], [{xmlcdata, N}]}
				       ]
	   }}),
    case R of
	{iq, [], result, [], _L, []} ->
	    {false, {response, [0]}};
	_ ->
	    {false, {response, [1]}}
    end;

%% add_rosteritem  struct[{localuser, String}, {localserver, String}, 
%%                  {user, String}, {server, String}, 
%%                  {nick, String}, {group, String}, 
%%                  {subs, String}]                                String
handler(_State, {call, add_rosteritem, [{struct, AttrL}]}) ->
    [Localuser, Localserver, User, Server, Nick, Group, Subs] = 
	get_attrs([localuser, localserver, user, server, nick, group, subs], AttrL),
    Node = node(),
    R = case add_rosteritem(Localuser, Localserver, User, Server, Nick, Group, list_to_atom(Subs), []) of
	    {atomic, ok} ->
		0;
	    {error, Reason} ->
		io:format("Can't add roster item to user ~p@~p on node ~p: ~p~n",
			  [Localuser, Localserver, Node, Reason]);
	    {badrpc, Reason} ->
		io:format("Can't add roster item to user ~p@~p on node ~p: ~p~n",
			  [Localuser, Localserver, Node, Reason])
	end,
    {false, {response, [R]}};

%% If no other guard matches
handler(_State, Payload) ->
    FaultString = lists:flatten(io_lib:format("Unknown call: ~p", [Payload])),
    ?INFO_MSG("Unknown call: ~p", [Payload]),
    {false, {response, {fault, -1, FaultString}}}.


%% -----------------------------
%% Internal
%% -----------------------------

get_title(A) -> mod_statsdx:get_title(A).
get_value(N, A) -> mod_statsdx:get(N, [A]).


add_rosteritem(LU, LS, User, Server, Nick, Group, Subscription, Xattrs) ->
    subscribe(LU, LS, User, Server, Nick, Group, Subscription, Xattrs).

subscribe(LU, LS, User, Server, Nick, Group, Subscription, Xattrs) ->
    mnesia:transaction(
      fun() ->
	      mnesia:write({roster,
			    {LU,LS,{User,Server,[]}}, % uj
			    {LU,LS},                  % user
			    {User,Server,[]},      % jid
			    Nick,                  % name: "Mom", []
			    Subscription,  % subscription: none, to=you see him, from=he sees you, both
			    none,          % ask: out=send request, in=somebody requests you, none
			    [Group],       % groups: ["Family"]
			    Xattrs,        % xattrs: [{"category","conference"}]
			    []             % xs: []
			   })
      end).

get_attrs(Attribute_names, L) ->
    [get_attr(A, L) || A <- Attribute_names].
get_attr(A, L) ->
    case lists:keysearch(A, 1, L) of 
	{value, {A, Value}} -> Value;
	false -> 
	    %% Report the error and then force a crash
	    ?ERROR_MSG("Attribute '~p' not found on the list of attributes provided on the call:~n ~p", [A, L]),
	    attribute_not_found = A
    end.

