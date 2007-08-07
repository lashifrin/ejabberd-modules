%%%----------------------------------------------------------------------
%%% File    : mod_multicast.erl
%%% Author  : Badlop <badlop@ono.com>
%%% Purpose : Extended Stanza Addressing (XEP-0033) support
%%% Created : 29 May 2007 by Badlop <badlop@ono.com>
%%% Id      : $Id$
%%%----------------------------------------------------------------------

-module(mod_multicast).
-author('badlop@ono.com').
-vsn('$Revision$ ').

-behaviour(gen_server).
-behaviour(gen_mod).

%% API
-export([start_link/2, start/2, stop/1]).

%% gen_server callbacks
-export([init/1,
	 handle_info/2,
	 handle_call/3,
	 handle_cast/2,
	 terminate/2,
	 code_change/3
	]).

-export([
	 route_packet_multicast/4,
	 purge_loop/1
	]).

-include("ejabberd.hrl").
-include("jlib.hrl").

-record(state, {lserver, lservice, access, max_receivers, limits}).

-record(multicastc, {rserver, response, ts}).
%% ts: timestamp (in seconds) when the cache item was last updated

-record(group, {server, dests, multicast}).
%% server = string()
%% dests = [string()] 
%% multicast = {cached, local_server} | {cached, string()} | {cached, not_supported} | {obsolete, not_supported} | {obsolete, string()} | not_cached
%%  after being updated, possible values are: local | multicast_not_supported | {multicast_supported, string()}

-record(waiter, {awaiting, group, renewal=false, sender, packet}).
%% awaiting = {[Remote_service], Local_service, Type_awaiting}
%%  Remote_service = Local_service = string()
%%  Type_awaiting = info | items
%% group = #group
%% renewal = true | false
%% sender = From
%% packet = xml()

-record(limits, {remote_user_message, remote_user_presence, 
		 remote_server_message, remote_server_presence,
		 local_user_message, local_user_presence, 
		 local_server_message, local_server_presence}).
%% All the elements are of type value()

-define(VERSION_MULTICAST, "$Revision$ ").
-define(PROCNAME, ejabberd_mod_multicast).

%% TODO: move this line to jlib.hrl
-define(NS_ADDRESS, "http://jabber.org/protocol/address").

-define(PURGE_PROCNAME, ejabberd_mod_multicast_purgeloop).

%% TODO: allow configuration instead of hard-coding
%% Time in seconds
-define(MAXTIME_CACHE_POSITIVE, 86400).
-define(MAXTIME_CACHE_NEGATIVE, 86400).

%% Time in miliseconds
-define(CACHE_PURGE_TIMER, 86400000). % Purge the cache every 24 hours
-define(DISCO_QUERY_TIMEOUT, 10000). % After 10 seconds of delay the server is declared dead

%% TODO: Put the correct values once XEP33 is updated
-define(DEFAULT_LIMIT_LOCAL_MESSAGE,  100).
-define(DEFAULT_LIMIT_LOCAL_PRESENCE, 100).
-define(DEFAULT_LIMIT_REMOTE_MESSAGE, 20).
-define(DEFAULT_LIMIT_REMOTE_PRESENCE,20).
-define(DEFAULT_LIMIT_UNRESTRICTED_MESSAGE,  infinite).
-define(DEFAULT_LIMIT_UNRESTRICTED_PRESENCE, infinite).


%%====================================================================
%% API
%%====================================================================
%%--------------------------------------------------------------------
%% Function: start_link() -> {ok,Pid} | ignore | {error,Error}
%% Description: Starts the server
%%--------------------------------------------------------------------
start_link(LServerS, Opts) ->
    Proc = gen_mod:get_module_proc(LServerS, ?PROCNAME),
    gen_server:start_link({local, Proc}, ?MODULE, [LServerS, Opts], []).

start(LServerS, Opts) ->
    Proc = gen_mod:get_module_proc(LServerS, ?PROCNAME),
    ChildSpec =	{
      Proc,
      {?MODULE, start_link, [LServerS, Opts]},
      temporary,
      1000,
      worker,
      [?MODULE]},
    supervisor:start_child(ejabberd_sup, ChildSpec).

stop(LServerS) ->
    Proc = gen_mod:get_module_proc(LServerS, ?PROCNAME),
    gen_server:call(Proc, stop),
    supervisor:terminate_child(ejabberd_sup, Proc),
    supervisor:delete_child(ejabberd_sup, Proc).


%%====================================================================
%% gen_server callbacks
%%====================================================================

%%--------------------------------------------------------------------
%% Function: init(Args) -> {ok, State} |
%%                         {ok, State, Timeout} |
%%                         ignore               |
%%                         {stop, Reason}
%% Description: Initiates the server
%%--------------------------------------------------------------------
init([LServerS, Opts]) ->
    LServiceS = gen_mod:get_opt(host, Opts, "multicast." ++ LServerS),
    Access = gen_mod:get_opt(access, Opts, all),
    Max_receivers = gen_mod:get_opt(max_receivers, Opts, 50),
    Limits = build_limit_record(gen_mod:get_opt(limits, Opts, [])),
    create_cache(),
    try_start_loop(),
    create_pool(),
    ejabberd_router:register_route(LServiceS),
    {ok, #state{lservice = LServiceS,
		lserver = LServerS,
		access = Access,
		max_receivers = Max_receivers,
		limits = Limits}}.

%%--------------------------------------------------------------------
%% Function: %% handle_call(Request, From, State) -> {reply, Reply, State} |
%%                                      {reply, Reply, State, Timeout} |
%%                                      {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, Reply, State} |
%%                                      {stop, Reason, State}
%% Description: Handling call messages
%%--------------------------------------------------------------------
handle_call(stop, _From, State) ->
    try_stop_loop(),
    {stop, normal, ok, State}.

%%--------------------------------------------------------------------
%% Function: handle_cast(Msg, State) -> {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, State}
%% Description: Handling cast messages
%%--------------------------------------------------------------------
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% Function: handle_info(Info, State) -> {noreply, State} |
%%                                       {noreply, State, Timeout} |
%%                                       {stop, Reason, State}
%% Description: Handling all non call/cast messages
%%--------------------------------------------------------------------

handle_info({route, From, To, {xmlelement, "iq", Attrs, _Els} = Packet}, State) ->
    IQ = jlib:iq_query_info(Packet),
    case catch process_iq(From, IQ, State) of
	Result when is_record(Result, iq) ->
	    ejabberd_router:route(To, From, jlib:iq_to_xml(Result));
	{'EXIT', Reason} ->
	    ?ERROR_MSG("Error when processing IQ stanza: ~p", [Reason]),
	    Err = jlib:make_error_reply(Packet, ?ERR_INTERNAL_SERVER_ERROR),
	    ejabberd_router:route(To, From, Err);
	reply ->
	    LServiceS = jlib:jid_to_string(To),
	    case xml:get_attr_s("type", Attrs) of
		"result" -> process_iqreply_result(From, LServiceS, Packet, State);
		"error" -> process_iqreply_error(From, LServiceS, Packet)
	    end
    end,
    {noreply, State};

%% XEP33 allows only 'message' and 'presence' stanza type
handle_info({route, From, To, {xmlelement, Stanza_type, _, _} = Packet},
	    #state{lservice = LServiceS,
		   lserver = LServerS,
		   access = Access,
		   max_receivers = Max_receivers,
		   limits = Limits} = State)
  when (Stanza_type == "message") or (Stanza_type == "presence") ->
    %%io:format("Multicast packet: ~nFrom: ~p~nTo: ~p~nPacket: ~p~n", [From, To, Packet]),
    case catch do_route(LServiceS, LServerS, Access, Max_receivers, From, To, Packet) of
	{'EXIT', Reason} ->
	    ?ERROR_MSG("~p", [Reason]);
	_ ->
	    ok
    end,
    {noreply, State};

handle_info({get_host, Pid}, State) ->
    Pid ! {my_host, State#state.lservice},
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% Function: terminate(Reason, State) -> void()
%% Description: This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any necessary
%% cleaning up. When it returns, the gen_server terminates with Reason.
%% The return value is ignored.
%%--------------------------------------------------------------------
terminate(_Reason, State) ->
    ejabberd_router:unregister_route(State#state.lservice),
    ok.

%%--------------------------------------------------------------------
%% Func: code_change(OldVsn, State, Extra) -> {ok, NewState}
%% Description: Convert process state when code is changed
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%%====================================================================
%%% Internal functions
%%====================================================================


%%%------------------------
%%% IQ Request Processing
%%%------------------------

%% disco#info request
process_iq(From, #iq{type = get, xmlns = ?NS_DISCO_INFO, lang = Lang} = IQ, State) ->
    IQ#iq{type = result, sub_el =
	  [{xmlelement, "query", [{"xmlns", ?NS_DISCO_INFO}], iq_disco_info(From, Lang, State)}]};

%% disco#items request
process_iq(_, #iq{type = get, xmlns = ?NS_DISCO_ITEMS} = IQ, _) ->
    IQ#iq{type = result, sub_el =
	  [{xmlelement, "query", [{"xmlns", ?NS_DISCO_ITEMS}], []}]};

%% vCard request
process_iq(_, #iq{type = get, xmlns = ?NS_VCARD, lang = Lang} = IQ, _) ->
    IQ#iq{type = result, sub_el =
	  [{xmlelement, "vCard", [{"xmlns", ?NS_VCARD}], iq_vcard(Lang)}]};

%% version request
process_iq(_, #iq{type = get, xmlns = ?NS_VERSION} = IQ, _) ->
    IQ#iq{type = result, sub_el =
	  [{xmlelement, "query", [{"xmlns", ?NS_VERSION}], iq_version()}]};

%% Unknown "set" or "get" request
process_iq(_, #iq{type=Type, sub_el=SubEl} = IQ, _) when Type==get; Type==set ->
    IQ#iq{type = error, sub_el = [SubEl, ?ERR_SERVICE_UNAVAILABLE]};

%% IQ "result" or "error".
process_iq(_, reply, _) ->
    reply;

%% IQ "result" or "error".
process_iq(_, _, _) ->
    ok.

-define(FEATURE(Feat), {xmlelement,"feature",[{"var", Feat}],[]}).

iq_disco_info(From, Lang, State) ->
    [{xmlelement, "identity",
      [{"category", "service"},
       {"type", "multicast"},
       {"name", translate:translate(Lang, "Multicast")}], []},
     ?FEATURE(?NS_DISCO_INFO),
     ?FEATURE(?NS_DISCO_ITEMS),
     ?FEATURE(?NS_VCARD),
     ?FEATURE(?NS_ADDRESS)] ++
	iq_disco_info_extras(From, State).

iq_vcard(Lang) ->
    [{xmlelement, "FN", [],
      [{xmlcdata, "ejabberd/mod_multicast"}]},
     {xmlelement, "URL", [],
      [{xmlcdata, ?EJABBERD_URI}]},
     {xmlelement, "DESC", [],
      [{xmlcdata, translate:translate(Lang, "ejabberd Multicast service\n"
				      "Copyright (c) 2007 Alexey Shchepin")}]}].

iq_version() ->
    [{xmlelement, "name", [],
      [{xmlcdata, "mod_multicast"}]},
     {xmlelement, "version", [],
      [{xmlcdata, ?VERSION_MULTICAST}]}].


%%%-------------------------
%%% Route 0: Check user
%%%-------------------------

do_route(LServiceS, LServerS, Access, Max_receivers, From, To, Packet) ->
    case acl:match_rule(LServerS, Access, From) of
	allow ->
	    do_route1(LServiceS, LServerS, Max_receivers, From, To, Packet);
	_ ->
	    route_error(To, From, Packet, forbidden, "Access denied by service policy")
    end.


%%%-------------------------
%%% Route 1: Check packet
%%%-------------------------

do_route1(LServiceS, LServerS, Max_receivers, From, To, Packet) ->
    case get_adrs_el(Packet) of
	{correct, Addresses_xml} ->
	    do_route2(LServiceS, LServerS, Max_receivers, From, To, Packet, Addresses_xml);
	{error, Error_text} ->
	    route_error(To, From, Packet, bad_request, Error_text)
    end.

get_adrs_el(Packet) ->
    case xml:get_subtag(Packet, "addresses") of
	{xmlelement, _, PAttrs, Addresses_xml} ->
	    case xml:get_attr_s("xmlns", PAttrs) of
		?NS_ADDRESS -> 
		    case get_address_els(Addresses_xml) of
			[] -> {error, "no address elements found"};
			Addresses -> {correct, Addresses}
		    end;
		_ -> {error, "wrong xmlns"}
	    end;
	_ -> {error, "no addresses element found"}
    end.

%% Given a list of xmlelements, some may be of "address" type,
%% return a list of only the attributes of those "address" elements
get_address_els(Addresses_xml) ->
    lists:foldl(
      fun(XML, R) ->
	      case XML of
		  {xmlelement, "address", Attrs, _El} ->
		      case xml:get_attr_s("delivered", Attrs) of
			  "true" -> R;
			  _ ->
			      Type = xml:get_attr_s("type", Attrs),
			      case Type of
				  "to" -> [Attrs|R];
				  "cc" -> [Attrs|R];
				  "bcc" -> [Attrs|R];
				  _ -> R
			      end
		      end;
		  _ -> R
	      end
      end,
      [],
      Addresses_xml).


%%%-------------------------
%%% Route 2: Format list of destinations
%%%-------------------------

do_route2(LServiceS, LServerS, Max_receivers, From1, To, Packet, Addresses) ->
    From = jlib:jid_to_string(From1),

    case length(Addresses) > Max_receivers of
	false -> ok;
	true ->
	    route_error(To, From, Packet, not_acceptable,
			"Too many receiver fields were specified")
    end,

    {JIDs, URIs, Others} = split_dests(Addresses),

    send_error_address(From1, Packet, URIs, Others),

    Grouped_addresses = group_dests_by_servers(JIDs),

    %% Check if this packet requires relay
    FromJID = jlib:string_to_jid(From),
    case check_relay_required(FromJID#jid.server, LServerS, Grouped_addresses) of
	false -> do_route3(LServiceS, LServerS, FromJID, Packet, Grouped_addresses);
	true ->
	    %% The packet requires relaying, but it is not allowed
	    %% So let's abort and return error
	    route_error(To, FromJID, Packet, forbidden,
			"Relaying denied by service policy")
    end.

%% Sends an error message for each unknown address
%% Currently only 'jid' addresses are acceptable on ejabberd
send_error_address(From, Packet, URIs, Others) ->
    URIs2 = ["uri: " ++ URI || URI <- URIs],
    Others2 = [io_lib:format("~p", [Other]) || Other <- Others],
    Unknown_adds = URIs2 ++ Others2,
    [route_error(From, From, Packet, jid_malformed, 
		 "The service does not understand the address: " ++ A)
     || A <- Unknown_adds].

%% Split the list of destinations depending on the address type
split_dests(Addresses) ->
    lists:foldl(
      fun(Addr, {Jids1, Uris1, Others1}) ->
	      {Jid2, Uri2, Other2} =
		  case {xml:get_attr_s("jid", Addr), xml:get_attr_s("uri", Addr)} of
		      {[], []} -> {[], [], [Addr]};
		      {Jid, []} -> {[Jid], [], []};
		      {[], Uri} -> {[], [Uri], []};
		      {_Jid, _Uri} -> {[], [], [Addr]}
		  end,
	      {Jids1 ++ Jid2, Uris1 ++ Uri2, Others1 ++ Other2}
      end,
      {[], [], []},
      Addresses).

%% Group destinations by their servers
group_dests_by_servers(Jids) ->
    D = lists:foldl(
	  fun(Jid, Dict) ->
		  ServerS = (stj(Jid))#jid.server,
		  dict:append(ServerS, Jid, Dict)
	  end,
	  dict:new(),
	  Jids),
    Keys = dict:fetch_keys(D),
    [ #group{server = Key, dests = dict:fetch(Key, D)} || Key <- Keys ].


%%%-------------------------
%%% Route 3: Look for cached responses
%%%-------------------------

do_route3(LServiceS, LServerS, From, Packet, Grouped_addresses) ->
    Maxtime_positive = ?MAXTIME_CACHE_POSITIVE,
    Maxtime_negative = ?MAXTIME_CACHE_NEGATIVE,

    %% Fill all the possible data from the cache
    Grouped_addresses2 = 
	lists:map(
	  fun(G) ->
		  Cached_response = 
		      search_server_on_cache(G#group.server, LServerS,
					     {Maxtime_positive, Maxtime_negative}),
		  G#group{multicast = Cached_response}
	  end,
	  Grouped_addresses),

    [process_group(LServiceS, From, Packet, Group) || Group <- Grouped_addresses2].


%%%-------------------------
%%% Process group: send packet or ask support
%%%-------------------------

process_group(LServiceS, From, Packet, Group) ->
    Server = Group#group.server,
    case Group#group.multicast of

	{cached, local_server} ->
	    %% Send a copy of the packet to each local user on Dests
	    [route_packet(From, ToUser, [], Packet) || ToUser <- Group#group.dests];

	{cached, not_supported} ->
	    %% Send a copy of the packet to each remote user on Dests
	    [route_packet(From, ToUser, [], Packet) || ToUser <- Group#group.dests];

	{cached, {multicast_supported, JID}} ->
	    %% XEP33 is supported by the server, thanks to this service
	    route_packet(From, JID, Group#group.dests, Packet);

	{obsolete, not_supported} ->
	    send_query_info(Server, LServiceS),
	    add_waiter(#waiter{awaiting = {[Server], LServiceS, info},
			       group = Group,
			       renewal = false,
			       sender = From,
			       packet = Packet
			      });

	{obsolete, {multicast_supported, Old_service}} ->
	    send_query_info(Old_service, LServiceS),
	    add_waiter(#waiter{awaiting = {[Old_service], LServiceS, info},
			       group = Group,
			       renewal = true,
			       sender = From,
			       packet = Packet
			      });

	not_cached ->
	    send_query_info(Server, LServiceS),
	    add_waiter(#waiter{awaiting = {[Server], LServiceS, info},
			       group = Group,
			       renewal = false,
			       sender = From,
			       packet = Packet
			      })

    end.

%% Build and send packet to this group of destinations
%% From = jid()
%% To = string()
%% Dests = [string()]
route_packet(From, To, Dests, Packet) ->
    Packet2 = update_addresses_xml(Packet, Dests),
    Packet3 = xml:replace_tag_attr("to", To, Packet2),
    ejabberd_router:route(From, stj(To), Packet3).


%%%-------------------------
%%% Check relay
%%%-------------------------

%% If the sender is external, and at least one destination is external,
%% then this package requires relaying
check_relay_required(RServer, LServerS, Grouped_addresses) ->
    case string:str(RServer, LServerS) > 0 of
	true -> false;
	false -> check_relay_required(LServerS, Grouped_addresses)
    end.

check_relay_required(LServerS, Grouped_addresses) ->
    lists:any(
      fun(Group) ->
	      Group#group.server /= LServerS
      end,
      Grouped_addresses).


%%%-------------------------
%%% Tags
%%%-------------------------

%% For each address which server is not the local one, add delivered=true
%% If the address' type == bcc, remove address from list
%% Dests = [string()]
update_addresses_xml(Packet, Dests) ->
    %% get addresses
    {xmlelement, _, PAttrs, Addresses_xml} = xml:get_subtag(Packet, "addresses"),
    Addresses_xml2 = 
	lists:map(
	  fun(XML) ->
		  case XML of
		      {xmlelement, "address", Attrs, _El} ->
			  case xml:get_attr_s("delivered", Attrs) of
			      "true" -> XML;
			      _ ->
				  JID = xml:get_attr_s("jid", Attrs),
				  Is_multicast_dest = lists:member(JID, Dests),
				  Type = xml:get_attr_s("type", Attrs),
				  case {Is_multicast_dest, Type} of
				      {true, _} -> XML;
				      {false, "to"} -> add_delivered(XML);
				      {false, "cc"} -> add_delivered(XML);
				      {false, "bcc"} -> [];
				      {false, _} -> XML
				  end
			  end;
		      {xmlcdata, _} -> [];
		      _ -> XML
		  end
	  end,
	  Addresses_xml),
    Addresses_elements = case lists:flatten(Addresses_xml2) of
			     [] -> [];
			     E -> [{xmlelement, "addresses", PAttrs, E}]
			 end,
    replace_tag_el("addresses", Addresses_elements, Packet).

add_delivered({xmlelement, Name, Attrs, Els}) ->
    Attrs2 = Attrs ++ [{"delivered", "true"}],
    {xmlelement, Name, Attrs2, Els}.

replace_tag_el(El, Elements, {xmlelement, Name, Attrs, Els}) ->
    Els1 = lists:keydelete(El, 2, Els),
    Els2 = Els1 ++ Elements,
    {xmlelement, Name, Attrs, Els2}.


%%%-------------------------
%%% Check protocol support: Send request
%%%-------------------------

%% Ask the server if it supports XEP33
send_query_info(RServerS, LServiceS) ->
    %% Don't ask a service which JID is "echo.*", 
    case string:str(RServerS, "echo.") of
	1 -> false;
	_ -> send_query(RServerS, LServiceS, ?NS_DISCO_INFO)
    end.

send_query_items(RServerS, LServiceS) ->
    send_query(RServerS, LServiceS, ?NS_DISCO_ITEMS).

send_query(RServerS, LServiceS, XMLNS) ->
    Packet = {xmlelement, "iq",
	      [{"to", RServerS}, {"type", "get"}],
	      [{xmlelement, "query", [{"xmlns", XMLNS}], []}]},

    ejabberd_router:route(stj(LServiceS), stj(RServerS), Packet).


%%%-------------------------
%%% Check protocol support: Receive response: Error
%%%-------------------------

process_iqreply_error(From, LServiceS, _Packet) ->
    %% We don't need to change the TO attribute in the outgoing XMPP packet,
    %% since ejabberd will do it

    %% We do not change the FROM attribute in the outgoing XMPP packet,
    %% this way the user will know what server reported the error

    FromS = jlib:jid_to_string(From),
    case search_waiter(FromS, LServiceS, info) of
	{found_waiter, Waiter} ->
	    received_awaiter(FromS, Waiter, LServiceS);
	_ -> ok
    end.


%%%-------------------------
%%% Check protocol support: Receive response: Disco
%%%-------------------------

process_iqreply_result(From, LServiceS, Packet, State) ->
    {xmlelement, "query", Attrs2, Els2} = xml:get_subtag(Packet, "query"),
    case xml:get_attr_s("xmlns", Attrs2) of
	?NS_DISCO_INFO ->
	    process_discoinfo_result(From, LServiceS, Els2, State);
	?NS_DISCO_ITEMS ->
	    process_discoitems_result(From, LServiceS, Els2)
    end.


%%%-------------------------
%%% Check protocol support: Receive response: Disco Info
%%%-------------------------

process_discoinfo_result(From, LServiceS, Els, _State) ->
    FromS = jlib:jid_to_string(From),
    case search_waiter(FromS, LServiceS, info) of
	{found_waiter, Waiter} ->
	    process_discoinfo_result2(FromS, LServiceS, Els, Waiter);
	_ -> 
	    ok
    end.

process_discoinfo_result2(FromS, LServiceS, Els, Waiter) ->
    %% Check the response, to see if it includes the XEP33 feature. If support ==
    Multicast_support = 
	lists:any(
	  fun(XML) ->
		  case XML of
		      {xmlelement, "feature", Attrs, _} ->
			  ?NS_ADDRESS == xml:get_attr_s("var", Attrs);
		      _ -> false
		  end
	  end,
	  Els),

    Group = Waiter#waiter.group,
    RServer = Group#group.server,

    case Multicast_support of
	true -> 
	    %% Store this response on cache
	    add_response(RServer, {multicast_supported, FromS}),

	    %% Send XEP33 packet to JID
	    FromM = Waiter#waiter.sender,
	    DestsM =  Group#group.dests,
	    PacketM = Waiter#waiter.packet,
	    RServiceM = FromS,
	    route_packet(FromM, RServiceM, DestsM, PacketM),

	    %% Remove from Pool
	    delo_waiter(Waiter);

	false -> 
	    %% So we now know that JID does not support XEP33
	    case FromS of

		RServer ->
		    %% We asked the server, now let's see if any component supports it:

		    %% Send disco#items query to JID
		    send_query_items(FromS, LServiceS),

		    %% Store on Pool
		    delo_waiter(Waiter),
		    add_waiter(Waiter#waiter{
				 awaiting = {[FromS], LServiceS, items},
				 renewal = false
				});

		%% We asked a component, and it does not support XEP33
		_ ->
		    received_awaiter(FromS, Waiter, LServiceS)

	    end
    end.


%%%-------------------------
%%% Check protocol support: Receive response: Disco Items
%%%-------------------------

process_discoitems_result(From, LServiceS, Els) ->

    %% Convert list of xmlelement into list of strings
    List = lists:foldl(
	     fun(XML, Res) ->
		     %% For each one, if it's "item", look for jid
		     case XML of
			 {xmlelement, "item", Attrs, _} ->
			     Res ++ [xml:get_attr_s("jid", Attrs)];
			 _ -> Res
		     end
	     end,
	     [],
	     Els),

    %% Send disco#info queries to each item
    [send_query_info(Item, LServiceS) || Item <- List],

    %% Search who was awaiting a disco#items response from this JID
    FromS = jlib:jid_to_string(From),
    {found_waiter, Waiter} = search_waiter(FromS, LServiceS, items),

    delo_waiter(Waiter),
    add_waiter(Waiter#waiter{
		 awaiting = {List, LServiceS, info},
		 renewal = false
		}).


%%%-------------------------
%%% Check protocol support: Receive response: Received awaiter
%%%-------------------------

received_awaiter(JID, Waiter, LServiceS) ->
    {JIDs, LServiceS, info} = Waiter#waiter.awaiting,
    delo_waiter(Waiter),
    Group = Waiter#waiter.group,
    RServer = Group#group.server,

    %% Remove this awaiter from the list of awaiting JIDs.
    case lists:delete(JID, JIDs) of

	[] ->
	    %% We couldn't find any service in this server that supports XEP33
	    case Waiter#waiter.renewal of

		false -> 
		    %% Store on cache the response
		    add_response(RServer, not_supported),

		    %% Send a copy of the packet to each remote user on Dests
		    From = Waiter#waiter.sender,
		    Packet = Waiter#waiter.packet,
		    [route_packet(From, ToUser, [], Packet) || ToUser <- Group#group.dests];

		true -> 
		    %% We asked this component because the cache 
		    %% said it would support XEP33, but it doesn't!
		    send_query_info(RServer, LServiceS),
		    add_waiter(Waiter#waiter{
				 awaiting = {[RServer], LServiceS, info},
				 renewal = false
				})
	    end;

	JIDs2 ->
	    %% Maybe other component on the server supports XEP33
	    add_waiter(Waiter#waiter{
			 awaiting = {JIDs2, LServiceS, info},
			 renewal = false
			})
    end.


%%%-------------------------
%%% Cache
%%%-------------------------

create_cache() ->
    mnesia:create_table(multicastc, [{ram_copies, [node()]},
				     {attributes, record_info(fields, multicastc)}]).

%% Add this response to the cache.
%% If a previous response still exists, it's overwritten
add_response(RServer, Response) ->
    Secs = calendar:datetime_to_gregorian_seconds(calendar:now_to_datetime(now())),
    mnesia:dirty_write(#multicastc{rserver = RServer,
				   response = Response,
				   ts = Secs}).

%% Search on the cache if there is a response for the server
%% If there is a response but is obsolete,
%% don't bother removing since it will later be overwritten anyway
search_server_on_cache(RServer, LServerS, _Maxmins)
  when RServer == LServerS ->
    {cached, local_server};

search_server_on_cache(RServer, _LServerS, Maxmins) ->
    case look_server(RServer) of
	not_cached ->
	    not_cached;
	{cached, Response, Ts} ->
	    Now = calendar:datetime_to_gregorian_seconds(calendar:now_to_datetime(now())),
	    case is_obsolete(Response, Ts, Now, Maxmins) of
		false -> {cached, Response};
		true -> {obsolete, Response}
	    end
    end.

look_server(RServer) ->
    case mnesia:dirty_read(multicastc, RServer) of
	[] -> not_cached;
	[M] -> {cached, M#multicastc.response, M#multicastc.ts}
    end.

is_obsolete(Response, Ts, Now, {Max_pos, Max_neg}) ->
    Max = case Response of
	      multicast_not_supported -> Max_neg;
	      _ -> Max_pos
	  end,
    (Now - Ts) > Max.


%%%-------------------------
%%% Purge cache
%%%-------------------------

purge() ->
    Maxmins_positive = ?MAXTIME_CACHE_POSITIVE,
    Maxmins_negative = ?MAXTIME_CACHE_NEGATIVE,
    Now = calendar:datetime_to_gregorian_seconds(calendar:now_to_datetime(now())),
    purge(Now, {Maxmins_positive, Maxmins_negative}).

purge(Now, Maxmins) ->
    F = fun() ->
		mnesia:foldl(
		  fun(R, _) ->
			  #multicastc{response = Response, ts = Ts} = R,
			  %% If this record is obsolete, delete it
			  case is_obsolete(Response, Ts, Now, Maxmins) of
			      true -> mnesia:delete_object(R);
			      false -> ok
			  end
		  end,
		  none,
		  multicastc)
	end,
    mnesia:transaction(F).


%%%-------------------------
%%% Purge cache loop
%%%-------------------------

try_start_loop() ->
    case lists:member(?PURGE_PROCNAME, registered()) of
	true -> ok;
	false -> start_loop()
    end,
    ?PURGE_PROCNAME ! new_module.

start_loop() ->
    register(?PURGE_PROCNAME, spawn(?MODULE, purge_loop, [0])),
    ?PURGE_PROCNAME ! purge_now.

try_stop_loop() ->
    ?PURGE_PROCNAME ! try_stop.

%% NM = number of modules are running on this node
purge_loop(NM) ->
    receive
	purge_now ->
	    purge(),
	    timer:send_after(?CACHE_PURGE_TIMER, ?PURGE_PROCNAME, purge_now),
	    purge_loop(NM);
	new_module ->
	    purge_loop(NM + 1);
	try_stop when NM > 1 ->
	    purge_loop(NM - 1);
	try_stop ->
	    purge_loop_finished
    end.


%%%-------------------------
%%% Pool
%%%-------------------------

create_pool() ->
    catch ets:new(multicastp, [duplicate_bag, public, named_table, {keypos, 2}]).

%% If a Waiter with the same key exists, it overwrites it
add_waiter(Waiter) ->
    true = ets:insert(multicastp, Waiter).

delo_waiter(Waiter) ->
    true = ets:delete_object(multicastp, Waiter).

%% Search on the Pool who is waiting for this result
%% If there are several matches, pick the first one only
search_waiter(JID, LServiceS, Type) ->
    Rs = ets:foldl(
	   fun(W, Res) ->
		   {JIDs, LServiceS1, Type1} = W#waiter.awaiting,
		   case lists:member(JID, JIDs) 
		       and (LServiceS == LServiceS1)
		       and (Type1 == Type) of
		       true -> Res ++ [W];
		       false -> Res
		   end
	   end,
	   [],
	   multicastp
	  ),
    case Rs of
	[R | _] -> {found_waiter, R};
	[] -> waiter_not_found
    end.


%%%-------------------------
%%% Limits: utils
%%%-------------------------

%% Type definitions for data structures related with XEP33 limits
%% limit() = {Name, Value}
%% Name = atom()
%% Value = {Type, Number}
%% Type = default | custom
%% Number = integer() | infinite

list_of_limits(local) ->
    [{local_message, ?DEFAULT_LIMIT_LOCAL_MESSAGE},
     {local_presence, ?DEFAULT_LIMIT_LOCAL_PRESENCE}];

list_of_limits(remote) ->
    [{remote_message, ?DEFAULT_LIMIT_REMOTE_MESSAGE},
     {remote_presence, ?DEFAULT_LIMIT_REMOTE_PRESENCE}].

list_of_limits() ->
    list_of_limits(local) ++
	list_of_limits(remote) ++
	[{unrestricted_message, ?DEFAULT_LIMIT_UNRESTRICTED_MESSAGE},
	 {unrestricted_presence, ?DEFAULT_LIMIT_UNRESTRICTED_PRESENCE}].

%% Build a record of type #limits{}
%% In fact, it builds a list and then converts to tuple
%% It is important to put the elements in the list in 
%% the same order than the elements in record #limits
build_limit_record(LimitOpts) ->
    Limits = [
	      get_limit_value(Name, Default, LimitOpts) 
	      || {Name, Default} <- list_of_limits()],
    list_to_tuple([limits | Limits]).

get_limit_value(Name, Default, LimitOpts) ->
    case lists:keysearch(Name, 1, LimitOpts) of
	{value, {Name, Number}} -> 
	    {custom, Number};
	false -> 
	    {default, Default}
    end.


%%%-------------------------
%%% Limits: XEP-0128 Service Discovery Extensions
%%%-------------------------

%% Some parts of code are borrowed from mod_muc_room.erl

-define(RFIELDT(Type, Var, Val),
	{xmlelement, "field", [{"var", Var}, {"type", Type}],
	 [{xmlelement, "value", [], [{xmlcdata, Val}]}]}).

-define(RFIELDV(Var, Val),
	{xmlelement, "field", [{"var", Var}],
	 [{xmlelement, "value", [], [{xmlcdata, Val}]}]}).

iq_disco_info_extras(From, State) ->
    SenderT = sender_type(From),
    io:format("se: ~p~n", [SenderT]),
    case iq_disco_info_extras2(SenderT, State) of
	[] -> [];
	List_limits_xmpp ->
	    [{xmlelement, "x", [{"xmlns", ?NS_XDATA}, {"type", "result"}],
	      [?RFIELDT("hidden", "FORM_TYPE", ?NS_ADDRESS)] ++ List_limits_xmpp
	     }]
    end.

sender_type(From) ->
    Local_hosts = ?MYHOSTS,
    case lists:member(From#jid.lserver, Local_hosts) of
	true -> local;
	false -> remote
    end.

iq_disco_info_extras2(SenderT, State) ->
    [limits | Limits_values] = tuple_to_list(State#state.limits),
    Limits_all = lists:zip(list_of_limits(), Limits_values),
    Limits_sender = list_of_limits(SenderT),
    [?RFIELDV(to_string(Name1), to_string(Number)) || 
	%% Report only custom limits
	{{Name1, _Default}, {custom, Number}} <- Limits_all,
	%% And report only the limits that are interesting for this sender
	{Name2, _} <- Limits_sender,
	Name1 == Name2].

to_string(A) ->
    hd(io_lib:format("~p",[A])).


%%%-------------------------
%%% Error report
%%%-------------------------

route_error(From, To, Packet, ErrType, ErrText) ->
    {xmlelement, _Name, Attrs, _Els} = Packet,
    Lang = xml:get_attr_s("xml:lang", Attrs),
    Reply = make_reply(ErrType, Lang, ErrText),
    Err = jlib:make_error_reply(Packet, Reply),
    ejabberd_router:route(From, To, Err).

make_reply(bad_request, Lang, ErrText) ->
    ?ERRT_BAD_REQUEST(Lang, ErrText);
make_reply(jid_malformed, Lang, ErrText) ->
    ?ERRT_JID_MALFORMED(Lang, ErrText);
make_reply(not_acceptable, Lang, ErrText) ->
    ?ERRT_NOT_ACCEPTABLE(Lang, ErrText);
make_reply(forbidden, Lang, ErrText) ->
    ?ERRT_FORBIDDEN(Lang, ErrText).

stj(String) -> jlib:string_to_jid(String).


%%%-------------------------
%%% Exported multicast functions 
%%%-------------------------

%% From = jid()
%% Destinations = [jid()]
%% Multicast_service = string()
route_packet_multicast(From, Destinations, Multicast_service, Packet) ->
    %% Build and addresses element
    Ad_list = [build_address_element(jlib:jid_to_string(JID)) || JID <- Destinations],
    Element = build_addresses_element(Ad_list),

    %% Add element to original packet
    {xmlelement, Type, Attrs, Els} = Packet,
    Els2 = [Element | Els],
    Packet_multicast = {xmlelement, Type, Attrs, Els2},

    %% Finally, send the packet to the multicast service
    ejabberd_router:route(
      From,
      jlib:string_to_jid(Multicast_service),
      Packet_multicast).

build_address_element(Jid_string) ->
    {xmlelement, "address", 
     [{"type", "bcc"}, {"jid", Jid_string}], 
     []}.

build_addresses_element(Addresses_list) ->
    {xmlelement, "addresses", 
     [{"xmlns", "http://jabber.org/protocol/address"}], 
     Addresses_list}.
