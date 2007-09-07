%%%----------------------------------------------------------------------
%%% File    : mod_pubsub.erl
%%% Author  : Alexey Shchepin <alexey@sevcom.net>
%%% Purpose : Pub/sub support (JEP-0060)
%%% Created :  4 Jul 2003 by Alexey Shchepin <alexey@sevcom.net>
%%% Id      : $Id$
%%%----------------------------------------------------------------------

-module(mod_pubsub).
-author('alexey@sevcom.net').
-vsn('$Revision$ ').

-behaviour(gen_server).
-behaviour(gen_mod).

%% API
-export([start_link/2,
	 start/2,
	 stop/1]).

-export([incoming_presence/3]).

-export([disco_local_identity/5,
	 disco_sm_identity/5,
	 disco_sm_features/5,
	 iq_pep_local/3,
	 iq_pep_sm/3,
	 pep_disco_items/5]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-define(ejabberd_debug, true).

-include("ejabberd.hrl").
-include("jlib.hrl").
-include("jlib-pep.hrl").

-record(state, {host, server_host, access}).

-define(DICT, dict).
%% XXX: this is currently a hard limit.  Would be nice to have it
%% configurable in certain cases.
-define(MAXITEMS, 20).
-define(MAX_PAYLOAD_SIZE, 100000).

-record(pubsub_node, {host_node, host_parent, info}).
-record(pubsub_presence, {key, resource}).	%key is {host, luser, lserver}
-record(pep_node, {owner_node, owner, info}).	%owner is {luser, lserver, ""}
-record(nodeinfo, {items = [],
		   options = [],
		   entities = ?DICT:new()
		  }).
-record(entity, {affiliation = none,
		 subscription = none}).
-record(item, {id, publisher, payload}).

get_node_info(#pubsub_node{info = Info}) -> Info;
get_node_info(#pep_node{info = Info}) -> Info.

set_node_info(#pubsub_node{} = N, NewInfo) -> N#pubsub_node{info = NewInfo};
set_node_info(#pep_node{} = N, NewInfo) -> N#pep_node{info = NewInfo}.

get_node_name(#pubsub_node{host_node = {_Host, Node}}) -> Node;
get_node_name(#pep_node{owner_node = {_Owner, Node}}) -> Node.

-define(PROCNAME, ejabberd_mod_pubsub).
-define(MYJID, #jid{user = "", server = Host, resource = "",
		    luser = "", lserver = Host, lresource = ""}).

-define(NS_PUBSUB_SUB_AUTH, "http://jabber.org/protocol/pubsub#subscribe_authorization").

%%====================================================================
%% API
%%====================================================================
%%--------------------------------------------------------------------
%% Function: start_link() -> {ok,Pid} | ignore | {error,Error}
%% Description: Starts the server
%%--------------------------------------------------------------------
start_link(Host, Opts) ->
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    gen_server:start_link({local, Proc}, ?MODULE, [Host, Opts], []).

start(Host, Opts) ->
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    ChildSpec =
	{Proc,
	 {?MODULE, start_link, [Host, Opts]},
	 transient,
	 1000,
	 worker,
	 [?MODULE]},
    supervisor:start_child(ejabberd_sup, ChildSpec).

stop(Host) ->
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    gen_server:call(Proc, stop),
    supervisor:stop_child(ejabberd_sup, Proc).

incoming_presence(From, #jid{lserver = Host} = To, Packet) ->
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    gen_server:cast(Proc, {presence, From, To, Packet}).

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
init([ServerHost, Opts]) ->
    mnesia:create_table(pubsub_node,
			[{disc_only_copies, [node()]},
			 {attributes, record_info(fields, pubsub_node)}]),
    mnesia:create_table(pep_node,
			[{disc_only_copies, [node()]},
			 {attributes, record_info(fields, pep_node)}]),
    mnesia:add_table_index(pep_node, owner),
    mnesia:create_table(pubsub_presence,
			[{ram_copies, [node()]},
			 {attributes, record_info(fields, pubsub_presence)},
			 {type, bag}]),
    mnesia:add_table_copy(pubsub_presence, node(), ram_copies),

    Host = gen_mod:get_opt(host, Opts, "pubsub." ++ ServerHost),
    update_table(Host),
    mnesia:add_table_index(pubsub_node, host_parent),
    ServedHosts = gen_mod:get_opt(served_hosts, Opts, []),
    Access = gen_mod:get_opt(access_createnode, Opts, all),

    mod_disco:register_feature(ServerHost, ?NS_PUBSUB),
    ejabberd_hooks:add(disco_local_identity, ServerHost, ?MODULE, disco_local_identity, 75),
    ejabberd_hooks:add(disco_sm_identity, ServerHost, ?MODULE, disco_sm_identity, 75),
    ejabberd_hooks:add(disco_sm_features, ServerHost, ?MODULE, disco_sm_features, 75),
    ejabberd_hooks:add(disco_sm_items, ServerHost, ?MODULE, pep_disco_items, 50),

    IQDisc = gen_mod:get_opt(iqdisc, Opts, one_queue),
    gen_iq_handler:add_iq_handler(ejabberd_local, ServerHost, ?NS_PUBSUB,
				  ?MODULE, iq_pep_local, IQDisc),
    gen_iq_handler:add_iq_handler(ejabberd_local, ServerHost, ?NS_PUBSUB_OWNER,
				  ?MODULE, iq_pep_local, IQDisc),
    gen_iq_handler:add_iq_handler(ejabberd_sm, ServerHost, ?NS_PUBSUB,
				  ?MODULE, iq_pep_sm, IQDisc),
    gen_iq_handler:add_iq_handler(ejabberd_sm, ServerHost, ?NS_PUBSUB_OWNER,
				  ?MODULE, iq_pep_sm, IQDisc),

    ejabberd_hooks:add(incoming_presence_hook, ServerHost, ?MODULE, incoming_presence, 50),

    ejabberd_router:register_route(Host),
    create_new_node(Host, ["pubsub"], ?MYJID),
    create_new_node(Host, ["pubsub", "nodes"], ?MYJID),
    create_new_node(Host, ["home"], ?MYJID),
    create_new_node(Host, ["home", ServerHost], ?MYJID),
    lists:foreach(fun(H) ->
			  create_new_node(Host, ["home", H], ?MYJID)
		  end, ServedHosts),
    {ok, #state{host = Host, server_host = ServerHost, access = Access}}.

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
    {stop, normal, ok, State}.

%%--------------------------------------------------------------------
%% Function: handle_cast(Msg, State) -> {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, State}
%% Description: Handling cast messages
%%--------------------------------------------------------------------
handle_cast({presence, From, To, Packet}, State) ->
    %% When we get available presence from a subscriber, send the last
    %% published item.
    Priority = case xml:get_subtag(Packet, "priority") of
		   false ->
		       0;
		   SubEl ->
		       case catch list_to_integer(xml:get_tag_cdata(SubEl)) of
			   P when is_integer(P) ->
			       P;
			   _ ->
			       0
		       end
	       end,
    PType = xml:get_tag_attr_s("type", Packet),
    Type = case PType of
	       "" -> 
		   if Priority < 0 ->
			   unavailable;
		      true ->
			   available
		   end;
	       "unavailable" -> unavailable;
	       "error" -> unavailable;
	       _ -> none
	   end,
    LJID = jlib:jid_tolower(jlib:jid_remove_resource(To)),
    PreviouslyAvailable =
	lists:member(From#jid.lresource,
		     get_present_resources(element(1, LJID), element(2, LJID),
					   From#jid.luser, From#jid.lserver)),
    Key = {To#jid.lserver, From#jid.luser, From#jid.lserver},
    Record = #pubsub_presence{key = Key, resource = From#jid.lresource},
    Host = case LJID of
	       {"", LServer, ""} ->
		   LServer;
	       _ ->
		   LJID
	   end,
    case Type of
	available ->
	    mnesia:dirty_write(Record);
	unavailable ->
	    mnesia:dirty_delete_object(Record);
	_ ->
	    ok
    end,
    if PreviouslyAvailable == false, Type == available ->
	    %% A new resource is available.  Loop through all nodes
	    %% and see if the contact is subscribed, and if so, and if
	    %% the node is so configured, send the last item.
	    Nodes = case Host of
			{_, _, _} ->
			    mnesia:dirty_index_read(pep_node, LJID, #pep_node.owner);
			_ ->
			    mnesia:dirty_match_object(#pubsub_node{host_node = {LJID, '_'}, _ = '_'})
		    end,
	    Features = case catch mod_caps:get_features(?MYNAME, 
							mod_caps:read_caps(element(4, Packet))) of
			   F when is_list(F) -> F;
			   _ -> []
		       end,
	    PresenceSubscribed =
		has_presence_subscription(To#jid.luser, To#jid.lserver,
					  jlib:jid_tolower(From)),
	    lists:foreach(
	      fun(N) ->
		      Node = get_node_name(N),
		      Info = get_node_info(N),
		      Subscription = get_subscription(Info, From),
		      SendWhen = get_node_option(Info, send_last_published_item),
		      %% If the contact has an explicit
		      %% subscription to the node, and the
		      %% node is so configured, send last
		      %% item.
		      if Subscription /= none, Subscription /= pending,
			 SendWhen == on_sub_and_presence ->
			      send_last_published_item(jlib:jid_tolower(From), Host, Node, Info);
			 PresenceSubscribed, SendWhen == on_sub_and_presence ->
			      %% Else, if the node is so configured, and the user sends entity
			      %% capabilities saying that it wants notifications, send last
			      %% item.
			      LookingFor = Node++"+notify",
			      case lists:member(LookingFor, Features) of
				  true ->
				      MaySubscribe =
					  case get_node_option(Info, access_model) of
					      %% open, whitelist, presence, roster, authorize
					      open -> true;
					      presence -> PresenceSubscribed;
					      whitelist -> false; % subscribers are added manually
					      authorize -> false; % likewise
					      roster ->
						  AllowedGroups = get_node_option(Info, access_roster_groups),
						  is_in_roster_group(To#jid.luser, To#jid.lserver,
								     jlib:jid_tolower(From), AllowedGroups)
					  end,
				      if MaySubscribe ->
					      send_last_published_item(jlib:jid_tolower(From), Host, Node, Info);
					 true ->
					      ok
				      end;
				  false ->
				      ok
			      end;
			 true ->
			      ok
		      end
	      end, Nodes),
	    {noreply, State};
       true ->
	    {noreply, State}
    end;

handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% Function: handle_info(Info, State) -> {noreply, State} |
%%                                       {noreply, State, Timeout} |
%%                                       {stop, Reason, State}
%% Description: Handling all non call/cast messages
%%--------------------------------------------------------------------
handle_info({route, From, To, Packet}, 
#state{server_host = ServerHost, access = Access} = State) ->
    case catch do_route(To#jid.lserver, ServerHost, Access, From, To, Packet) of
	{'EXIT', Reason} ->
	    ?ERROR_MSG("~p", [Reason]);
	_ ->
	    ok
    end,
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
    #state{host = Host, server_host = ServerHost} = State,
    mod_disco:unregister_feature(ServerHost, ?NS_PUBSUB),
    ejabberd_hooks:delete(disco_local_identity, ServerHost, ?MODULE, disco_local_identity, 75),
    ejabberd_hooks:delete(disco_sm_identity, ServerHost, ?MODULE, disco_sm_identity, 75),
    ejabberd_hooks:delete(disco_sm_features, ServerHost, ?MODULE, disco_sm_features, 75),
    ejabberd_hooks:delete(disco_sm_items, ServerHost, ?MODULE, pep_disco_items, 50),
    gen_iq_handler:remove_iq_handler(ejabberd_local, ServerHost, ?NS_PUBSUB),
    gen_iq_handler:remove_iq_handler(ejabberd_local, ServerHost, ?NS_PUBSUB_OWNER),
    gen_iq_handler:remove_iq_handler(ejabberd_sm, ServerHost, ?NS_PUBSUB),
    gen_iq_handler:remove_iq_handler(ejabberd_sm, ServerHost, ?NS_PUBSUB_OWNER),
    ejabberd_hooks:delete(incoming_presence_hook, ServerHost, ?MODULE, incoming_presence, 50),
    ejabberd_router:unregister_route(Host),
    ok.

%%--------------------------------------------------------------------
%% Func: code_change(OldVsn, State, Extra) -> {ok, NewState}
%% Description: Convert process state when code is changed
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------
do_route(Host, ServerHost, Access, From, To, Packet) ->
    {xmlelement, Name, Attrs, _Els} = Packet,
    case To of
	#jid{luser = "", lresource = ""} ->
	    case Name of
		"iq" ->
		    case jlib:iq_query_info(Packet) of
			#iq{type = get, xmlns = ?NS_DISCO_INFO,
			    sub_el = SubEl} = IQ ->
			    {xmlelement, _, QAttrs, _} = SubEl,
			    Node = xml:get_attr_s("node", QAttrs),
			    Res = 
				case iq_disco_info(Host, From, Node) of
				    {result, IQRes} ->
					jlib:iq_to_xml(
					  IQ#iq{type = result,
						sub_el = [{xmlelement, "query",
							   QAttrs,
							   IQRes}]});
				    {error, Error} ->
					jlib:make_error_reply(
					  Packet, Error)
				end,
			    ejabberd_router:route(To, From, Res);
			#iq{type = get, xmlns = ?NS_DISCO_ITEMS,
			    sub_el = SubEl} = IQ ->
			    {xmlelement, _, QAttrs, _} = SubEl,
			    Node = xml:get_attr_s("node", QAttrs),
			    Res =
				case iq_disco_items(Host, From, Node) of
				    {result, IQRes} ->
					jlib:iq_to_xml(
					  IQ#iq{type = result,
						sub_el = [{xmlelement, "query",
							   QAttrs,
							   IQRes}]});
				    {error, Error} ->
					jlib:make_error_reply(
					  Packet, Error)
				end,
			    ejabberd_router:route(To, From, Res);
			#iq{type = Type, xmlns = ?NS_PUBSUB,
			    sub_el = SubEl} = IQ ->
			    Res =
				case iq_pubsub(Host, ServerHost, From, Type, SubEl, Access) of
				    {result, IQRes} ->
					jlib:iq_to_xml(
					  IQ#iq{type = result,
						sub_el = IQRes});
				    {error, Error} ->
					jlib:make_error_reply(
					  Packet, Error)
				end,
			    ejabberd_router:route(To, From, Res);
			#iq{type = Type, xmlns = ?NS_PUBSUB_OWNER,
			    lang = Lang, sub_el = SubEl} = IQ ->
			    Res =
				case iq_pubsub_owner(
				       Host, From, Type, Lang, SubEl) of
				    {result, IQRes} ->
					jlib:iq_to_xml(
					  IQ#iq{type = result,
						sub_el = IQRes});
				    {error, Error} ->
					jlib:make_error_reply(
					  Packet, Error)
				end,
			    ejabberd_router:route(To, From, Res);
			#iq{type = get, xmlns = ?NS_VCARD = XMLNS,
			    lang = Lang} = IQ ->
			    Res = IQ#iq{type = result,
					sub_el = [{xmlelement, "vCard",
						   [{"xmlns", XMLNS}],
						   iq_get_vcard(Lang)}]},
			    ejabberd_router:route(To,
						  From,
						  jlib:iq_to_xml(Res));
			#iq{} ->
			    Err = jlib:make_error_reply(
				    Packet,
				    ?ERR_FEATURE_NOT_IMPLEMENTED),
			    ejabberd_router:route(To, From, Err);
			_ ->
			    ok
		    end;
		"presence" ->
		    %% XXX: subscriptions?
		    incoming_presence(From, To, Packet),
		    ok;
		"message" ->
		    %% So why would anyone want to send messages to a
		    %% pubsub service?  Subscription authorization
		    %% (section 8.6).
		    case xml:get_attr_s("type", Attrs) of
			"error" ->
			    ok;
			_ ->
			    case find_authorization_response(Packet) of
				none ->
				    ok;
				invalid ->
				    ejabberd_router:route(To, From,
							  jlib:make_error_reply(Packet, ?ERR_BAD_REQUEST));
				XFields ->
				    handle_authorization_response(From, To, Host, Packet, XFields)
			    end
		    end
	    end;
	_ ->
	    case xml:get_attr_s("type", Attrs) of
		"error" ->
		    ok;
		"result" ->
		    ok;
		_ ->
		    Err = jlib:make_error_reply(
			    Packet, ?ERR_ITEM_NOT_FOUND),
		    ejabberd_router:route(To, From, Err)
	    end
    end.



node_to_string(Node) ->
    %% Flat (PEP) or normal node?
    case Node of
	[[_ | _] | _] ->
	    string:strip(lists:flatten(lists:map(fun(S) -> [S, "/"] end, Node)),
			 right, $/);
	[Head | _] when is_integer(Head) ->
	    Node
    end.

disco_local_identity(Acc, _From, _To, [], _Lang) ->
    Acc ++
	[{xmlelement, "identity",
	  [{"category", "pubsub"},
	   {"type", "pep"}], []}];
disco_local_identity(Acc, _From, _To, _Node, _Lang) ->
    Acc.

disco_sm_identity(Acc, _From, _To, [], _Lang) ->
    Acc ++
	[{xmlelement, "identity",
	  [{"category", "pubsub"},
	   {"type", "pep"}], []}];
disco_sm_identity(Acc, From, To, Node, _Lang) ->
    LOwner = jlib:jid_tolower(jlib:jid_remove_resource(To)),
    Identity =
	case node_disco_identity(LOwner, From, Node) of
	    {result, I} -> I;
	    _ -> []
	end,
    Acc ++ Identity.

disco_sm_features(Acc, _From, _To, [], _Lang) ->
    Acc;
disco_sm_features(Acc, From, To, Node, _Lang) ->
    LOwner = jlib:jid_tolower(jlib:jid_remove_resource(To)),
    Features = node_disco_features(LOwner, From, Node),
    case {Acc, Features} of
	{{result, AccFeatures}, {result, PepFeatures}} ->
	    {result, AccFeatures++PepFeatures};
	{_, {result, PepFeatures}} ->
	    {result, PepFeatures};
	{_, _} ->
	    Acc
    end.

node_disco_info(Host, From, Node) ->
    node_disco_info(Host, From, Node, true, true).
node_disco_identity(Host, From, Node) ->
    node_disco_info(Host, From, Node, true, false).
node_disco_features(Host, From, Node) ->
    node_disco_info(Host, From, Node, false, true).

node_disco_info(Host, _From, Node, Identity, Features) ->
    Table = get_table(Host),
    case catch mnesia:dirty_read({Table, {Host, Node}}) of
	[NodeData] ->
	    NodeInfo = get_node_info(NodeData),

	    I = case Identity of
		    false -> [];
		    true ->
			%% Now, let's shoehorn the ejabberd pubsub
			%% data model into the categories of the XEP :-)
			Types =
			    if Table == pep_node ->
				    %% In PEP, there are only leaf nodes.
				    ["leaf"];
			       true ->
				    SubNodes = mnesia:dirty_index_read(pubsub_node,
								       {Host, Node},
								       #pubsub_node.host_parent),
				    case {SubNodes, NodeInfo#nodeinfo.items} of
					{[], _} ->
					    %% No sub-nodes: it's a leaf node
					    ["leaf"];
					{[_|_], []} ->
					    %% Only sub-nodes: it's a collection node
					    ["collection"];
					{[_|_], [_|_]} ->
					    %% Both items and sub-nodes: it's both
					    ["leaf", "collection"]
				    end
			    end,
			lists:map(fun(Type) ->
					  {xmlelement, "identity",
					   [{"category", "pubsub"},
					    {"type", Type}], []}
				  end, Types)
		end,
	    
	    F = case {Features, Table} of
		    {false, _} -> [];
		    {true, _} ->
			%% Hm... what features are supposed to be reported?
			[]
		end,
	    
	    {result, I++F};
	[] ->
	    {error, ?ERR_ITEM_NOT_FOUND};
	_ ->
	    {error, ?ERR_INTERNAL_SERVER_ERROR}
    end.
		

get_table(Host) ->
    case Host of
	{_, _, _} -> pep_node;
	_ -> pubsub_node
    end.

get_sender(Host) ->
    case Host of
	{_, _, _} ->
	    jlib:make_jid(Host);
	_ ->
	    jlib:make_jid("", Host, "")
    end.

iq_pep_local(From, To, 
	     #iq{type = Type, sub_el = SubEl, xmlns = XMLNS, lang = Lang} = IQ) ->
    ServerHost = To#jid.lserver,
    %% Accept IQs to server only from our own users.
    if From#jid.lserver /= ServerHost ->
	    IQ#iq{type = error, sub_el = [?ERR_FORBIDDEN, SubEl]};
       true ->
	    LOwner = jlib:jid_tolower(jlib:jid_remove_resource(From)),
	    Res = case XMLNS of
		      ?NS_PUBSUB ->
			  %% XXX: "access all" correct?  it corresponds to access_createnode.
			  iq_pubsub(LOwner, ServerHost, From, Type, SubEl, all);
		      ?NS_PUBSUB_OWNER ->
			  iq_pubsub_owner(LOwner, From, Type, Lang, SubEl)
		  end,
	    case Res of
		{result, IQRes} ->
		    IQ#iq{type = result, sub_el = IQRes};
		{error, Error} ->
		    IQ#iq{type = error, sub_el = [Error, SubEl]}
	    end
    end.

iq_pep_sm(From, To, 
	  #iq{type = Type, sub_el = SubEl, xmlns = XMLNS, lang = Lang} = IQ) ->
    ServerHost = To#jid.lserver,
    LOwner = jlib:jid_tolower(jlib:jid_remove_resource(To)),
    Res = case XMLNS of
	      ?NS_PUBSUB ->
		  iq_pubsub(LOwner, ServerHost, From, Type, SubEl, all);
	      ?NS_PUBSUB_OWNER ->
		  iq_pubsub_owner(LOwner, From, Type, Lang, SubEl)
	  end,
    case Res of
	{result, IQRes} ->
	    IQ#iq{type = result, sub_el = IQRes};
	{error, Error} ->
	    IQ#iq{type = error, sub_el = [Error, SubEl]}
    end.

iq_disco_info(Host, From, SNode) ->
    Table = get_table(Host),
    Node = case Table of
	       pubsub_node ->
		   string:tokens(SNode, "/");
	       pep_node ->
		   SNode
	   end,
    case Node of
	[] ->
	    PubsubFeatures =
		["config-node",
		 "create-and-configure",
		 "create-nodes",
		 "delete-nodes",
		 %% "get-pending",
		 "instant-nodes",
		 "item-ids",
		 %% "manage-subscriptions",
		 %% "modify-affiliations",
		 "outcast-affiliation",
		 "persistent-items",
		 "presence-notifications",
		 "publish",
		 "publisher-affiliation",
		 "purge-nodes",
		 "retract-items",
		 "retrieve-affiliations",
		 %% "retrieve-default",
		 "retrieve-items",
		 "retrieve-subscriptions",
		 "subscribe"
		 %% , "subscription-notifications"
		 ],
	    {result,
	     [{xmlelement, "identity",
	       [{"category", "pubsub"},
		{"type", "service"},
		{"name", "Publish-Subscribe"}], []},
	      {xmlelement, "feature", [{"var", ?NS_PUBSUB}], []},
	      {xmlelement, "feature", [{"var", ?NS_VCARD}], []}] ++
	     lists:map(fun(Feature) ->
			       {xmlelement, "feature",
				[{"var", ?NS_PUBSUB++"#"++Feature}], []}
		       end, PubsubFeatures)};
	_ ->
	    node_disco_info(Host, From, Node)
    end.

iq_disco_items(Host, _From, SNode) ->
	{Node,ItemID} = case SNode of
	[] ->
		{[],none};
	_ ->
		Tokens = string:tokens(SNode, "!"),
		NodeList = string:tokens(lists:nth(1, Tokens), "/"),
		ItemName = case length(Tokens) of
		2 -> lists:nth(2, Tokens);
		_ -> none
		end,
		{NodeList, ItemName}
	end,
	%%NodeFull = string:tokens(SNode,"/"),
    F = fun() ->
		case mnesia:read({pubsub_node, {Host, Node}}) of
		    [#pubsub_node{info = Info}] ->
			case ItemID of
			none ->
				SubNodes = mnesia:index_read(pubsub_node,
						     {Host, Node},
						     #pubsub_node.host_parent),
				SubItems = lists:map(fun(#pubsub_node{host_node = {_, N}}) ->
					      SN = node_to_string(N),
					      {xmlelement, "item",
					       [{"jid", Host},
						{"node", SN},
						{"name", lists:last(N)}], []}
				      end, SubNodes),
				SN = node_to_string(Node),
				Items = lists:map(fun(#item{id = Name}) ->
						RealName = case Name of
						[] -> "item";
						_ -> Name
						end,
					      {xmlelement, "item",
					       [{"jid", Host},
						{"node", SN ++ "!" ++ Name},
						{"name", RealName}], []}
				      end, Info#nodeinfo.items),
				SubItems ++ Items;
			_ ->
				[]
			end;
		    [] ->
			case Node of
			    [] ->
				SubNodes = mnesia:index_read(
					     pubsub_node,
					     {Host, Node},
					     #pubsub_node.host_parent),
				lists:map(
				  fun(#pubsub_node{host_node = {_, N}}) ->
					  SN = node_to_string(N),
					  {xmlelement, "item",
					   [{"jid", Host},
					    {"node", SN},
					    {"name", lists:last(N)}],
					   []}
				  end, SubNodes) ;
			    _ ->
				{error, ?ERR_ITEM_NOT_FOUND}
			end
		end
	end,
    case mnesia:transaction(F) of
	{atomic, {error, _} = Error} ->
	    Error;
	{atomic, Res} ->
	    {result, Res};
	_ ->
	    {error, ?ERR_INTERNAL_SERVER_ERROR}
    end.

pep_disco_items(Acc, _From, To, "", _Lang) ->
    LJID = jlib:jid_tolower(jlib:jid_remove_resource(To)),
    case catch mnesia:dirty_index_read(pep_node, LJID, #pep_node.owner) of
	{'EXIT', Reason} ->
	    ?ERROR_MSG("~p", [Reason]),
	    Acc;
	[] ->
	    Acc;
	Nodes ->
	    Items = case Acc of
			{result, I} -> I;
			_ -> []
		    end,
	    NodeItems = lists:map(
			  fun(#pep_node{owner_node = {_, Node}}) ->
				  {xmlelement, "item",
				   [{"jid", jlib:jid_to_string(LJID)},
				    {"node", node_to_string(Node)}],
				   []}
			  end, Nodes),
	    {result, NodeItems ++ Items}
    end;
pep_disco_items(Acc, _From, _To, _Node, _Lang) ->
    Acc.

iq_get_vcard(Lang) ->
    [{xmlelement, "FN", [],
      [{xmlcdata, "ejabberd/mod_pubsub"}]},
     {xmlelement, "URL", [],
      [{xmlcdata,
	"http://ejabberd.jabberstudio.org/"}]},
     {xmlelement, "DESC", [],
      [{xmlcdata, translate:translate(
		    Lang,
		    "ejabberd pub/sub module\n"
		    "Copyright (c) 2003-2006 Alexey Shchepin")}]}].


iq_pubsub(Host, ServerHost, From, Type, SubEl, Access) ->
    %% Host may be a jid tuple, in which case we use PEP.
    {xmlelement, _, _, SubEls} = SubEl,
    WithoutCdata = xml:remove_cdata(SubEls),
    Configuration = lists:filter(fun({xmlelement, Name, _, _}) ->
					 Name == "configure"
				 end, WithoutCdata),
    Action = WithoutCdata -- Configuration,
    case Action of
	[{xmlelement, Name, Attrs, Els}] ->
	    %% For PEP, there is no node hierarchy.
	    Node = case Host of
		       {_, _, _} ->
			    xml:get_attr_s("node", Attrs);
		       _ ->
			   SNode = xml:get_attr_s("node", Attrs),
			   string:tokens(SNode, "/")
		   end,
	    case {Type, Name} of
		{set, "create"} ->
		    case Configuration of
			[{xmlelement, "configure", _, Config}] ->
			    create_new_node(Host, Node, From, ServerHost, Access, Config);
			_ ->
			    ?INFO_MSG("Invalid configuration: ~p", [Configuration]),
			    {error, ?ERR_BAD_REQUEST}
		    end;
		{set, "publish"} ->
		    case xml:remove_cdata(Els) of
			[{xmlelement, "item", ItemAttrs, Payload}] ->
			    ItemID = xml:get_attr_s("id", ItemAttrs),
			    publish_item(Host, From, Node, ItemID, Payload);
			_ ->
			    {error, ?ERR_BAD_REQUEST}
		    end;
		{set, "retract"} ->
		    ForceNotify =
			case xml:get_attr_s("notify", Attrs) of
			    "1" -> true;
			    "true" -> true;
			    _ -> false
			end,
		    case xml:remove_cdata(Els) of
			[{xmlelement, "item", ItemAttrs, _}] ->
			    ItemID = xml:get_attr_s("id", ItemAttrs),
			    delete_item(Host, From, Node, ItemID, ForceNotify);
			_ ->
			    {error, extend_error(?ERR_BAD_REQUEST, "item-required")}
		    end;
		{set, "subscribe"} ->
		    JID = xml:get_attr_s("jid", Attrs),
		    subscribe_node(Host, From, JID, Node);
		{set, "unsubscribe"} ->
		    JID = xml:get_attr_s("jid", Attrs),
		    unsubscribe_node(Host, From, JID, Node);
		{get, "items"} ->
		    MaxItems = xml:get_attr_s("max_items", Attrs),
		    get_items(Host, From, Node, MaxItems);
		{get, "affiliations"} ->
		    get_affiliations(Host, From);
		{get, "subscriptions"} ->
		    get_subscriptions(Host, From);
		_ ->
		    {error, ?ERR_FEATURE_NOT_IMPLEMENTED}
	    end;
	_ ->
	    ?INFO_MSG("Too many actions: ~p", [Action]),
	    {error, ?ERR_BAD_REQUEST}
    end.


-define(XFIELD(Type, Label, Var, Val),
	{xmlelement, "field", [{"type", Type},
			       {"label", translate:translate(Lang, Label)},
			       {"var", Var}],
	 [{xmlelement, "value", [], [{xmlcdata, Val}]}]}).

-define(BOOLXFIELD(Label, Var, Val),
	?XFIELD("boolean", Label, Var,
		case Val of
		    true -> "1";
		    _ -> "0"
		end)).

-define(STRINGXFIELD(Label, Var, Val),
	?XFIELD("text-single", Label, Var, Val)).

-define(XFIELDOPT(Type, Label, Var, Val, Opts),
	{xmlelement, "field", [{"type", Type},
			       {"label", translate:translate(Lang, Label)},
			       {"var", Var}],
	 lists:map(fun(Opt) ->
			   {xmlelement, "option", [],
			    [{xmlelement, "value", [],
			      [{xmlcdata, Opt}]}]}
		   end, Opts) ++
	 [{xmlelement, "value", [], [{xmlcdata, Val}]}]}).

-define(LISTXFIELD(Label, Var, Val, Opts),
	?XFIELDOPT("list-single", Label, Var, Val, Opts)).



%% Create new pubsub nodes
%% This function is used during init to create the first bootstrap nodes
create_new_node(Host, Node, Owner) ->
    %% This is the case use during "bootstrapping to create the initial
    %% hierarchy. Should always be ... undefined,all
    create_new_node(Host, Node, Owner, undefined, all, []).
create_new_node(Host, Node, Owner, ServerHost, Access, Configuration) ->
    DefaultSet = get_table(Host),		% get_table happens to DTRT here
    ConfigOptions = case xml:remove_cdata(Configuration) of
			[] ->
			    [{defaults, DefaultSet}];
			[{xmlelement, "x", _Attrs, _SubEls} = XEl] ->
			    case jlib:parse_xdata_submit(XEl) of
				invalid ->
				    {error, ?ERR_BAD_REQUEST};
				XData ->
				    case set_xoption(XData, [{defaults, DefaultSet}]) of
					NewOpts when is_list(NewOpts) ->
					    NewOpts;
					Err ->
					    Err
				    end
			    end;
			_ ->
			    ?INFO_MSG("Configuration not understood: ~p", [Configuration]),
			    {error, ?ERR_BAD_REQUEST}
		    end,
    case {Host, Node, ConfigOptions} of
	{_, _, {error, _} = Error} ->
	    Error;
	%% If Host is a jid tuple, we are in PEP.
	{{_, _, _}, [], _} ->
	    %% And in PEP, instant nodes are not supported.
	    {error, extend_error(?ERR_NOT_ACCEPTABLE, "nodeid-required")};
	{{_, _, _}, _, _} ->
	    LOwner = jlib:jid_tolower(jlib:jid_remove_resource(Owner)),
	    if LOwner == Host ->
		    F = fun() ->
				case mnesia:read({pep_node, {LOwner, Node}}) of
				    [_] ->
					{error, ?ERR_CONFLICT};
				    [] ->
					Entities =
					    ?DICT:store(
					       LOwner,
					       #entity{affiliation = owner,
						       subscription = none},
					       ?DICT:new()),
					mnesia:write(
					  #pep_node{owner_node = {LOwner, Node},
						    owner = LOwner,
						    info = #nodeinfo{entities = Entities,
								     options = ConfigOptions}}),
					ok
				end
			end,
		    case mnesia:transaction(F) of
			{atomic, ok} ->
			    {result, []};
			{atomic, {error, _} = Error} ->
			    Error;
			_ ->
			    {error, ?ERR_INTERNAL_SERVER_ERROR}
		    end;
	       true ->
		    {error, ?ERR_NOT_ALLOWED}
	    end;
	{_, [], _} ->
	    {LOU, LOS, _} = jlib:jid_tolower(Owner),
	    HomeNode = ["home", LOS, LOU],
	    create_new_node(Host, HomeNode, Owner, ServerHost, Access, []),
	    NewNode = ["home", LOS, LOU, randoms:get_string()],
	    %% When creating an instant node, we need to include the
	    %% node name in the result.
	    case create_new_node(Host, NewNode, Owner, ServerHost, Access, []) of
		{result, []} ->
		    {result,
		     [{xmlelement, "pubsub",
		       [{"xmlns", ?NS_PUBSUB}],
		       [{xmlelement, "create",
			 [{"node", node_to_string(NewNode)}], []}]}]};
		{error, _} = Error ->
		    Error
	    end;
	{_, _, _} ->
	    LOwner = jlib:jid_tolower(jlib:jid_remove_resource(Owner)),
	    Parent = lists:sublist(Node, length(Node) - 1),
	    F = fun() ->
			ParentExists = (Parent == []) orelse
			    case mnesia:read({pubsub_node, {Host, Parent}}) of
				[_] ->
				    true;
				[] ->
				    false
			    end,
			case ParentExists of
			    false ->
				{error, ?ERR_CONFLICT};
			    _ ->
				case mnesia:read({pubsub_node, {Host, Node}}) of
				    [_] ->
					{error, ?ERR_CONFLICT};
				    [] ->
					Entities =
					    ?DICT:store(
					       LOwner,
					       #entity{affiliation = owner,
						       subscription = none},
					       ?DICT:new()),
					mnesia:write(
					  #pubsub_node{host_node = {Host, Node},
						       host_parent = {Host, Parent},
						       info = #nodeinfo{
							 entities = Entities,
							 options = ConfigOptions}}),
					ok
				end
			end
		end,
	    case check_create_permission(Host, Node, Owner, ServerHost, Access) of
		true ->
		    case mnesia:transaction(F) of
			{atomic, ok} ->
			    Lang = "",
			    broadcast_publish_item(
			      Host, ["pubsub", "nodes"], node_to_string(Node),
			      [{xmlelement, "x",
				[{"xmlns", ?NS_XDATA},
				 {"type", "result"}],
				[?XFIELD("hidden", "", "FORM_TYPE",
					 ?NS_PUBSUB_NMI),
				 ?XFIELD("jid-single", "Node Creator",
					 "creator",
					 jlib:jid_to_string(LOwner))]}],
			      none),
			    {result, []};
			{atomic, {error, _} = Error} ->
			    Error;
			_ ->
			    {error, ?ERR_INTERNAL_SERVER_ERROR}
		    end;
		_ ->
		    {error, ?ERR_NOT_ALLOWED}
	    end
    end.


publish_item(Host, JID, Node, ItemID, Payload) ->
    Publisher = jlib:jid_tolower(jlib:jid_remove_resource(JID)),
    Table = get_table(Host),
    %% XXX: Host is not a host if this is PEP.  Good thing that this
    %% hook isn't added to anywhere yet.
    ejabberd_hooks:run(pubsub_publish_item, Host,
		       [JID, ?MYJID, Node, ItemID, Payload]),
    F = fun() ->
		NodeData =
		    case {Table, mnesia:read({Table, {Host, Node}})} of
			{_, [ND]} ->
			    [ND];
			{pubsub_node, []} ->
			    {error, ?ERR_ITEM_NOT_FOUND};
			{pep_node, []} ->
			    %% In PEP, nodes are created automatically
			    %% on publishing.
			    if Publisher == Host ->
				    case create_new_node(Host, Node, Host) of
					{error, _} = E ->
					    E;
					{result, _} ->
					    mnesia:read({Table, {Host, Node}})
				    end;
			       true ->
				    {error, ?ERR_NOT_ALLOWED}
			    end
		    end,
		case NodeData of
		    [N] ->
			Info = get_node_info(N),
			Affiliation = get_affiliation(Info, Publisher),
			Subscription = get_subscription(Info, Publisher),
			MaxSize = get_node_option(Info, max_payload_size),
			Model = get_node_option(Info, publish_model),
			Size = size(term_to_binary(Payload)),
			if
			    not ((Model == open) or
				 ((Model == publishers) and
				  ((Affiliation == owner) or
				   (Affiliation == publisher))) or
				 ((Model == subscribers) and
				  (Subscription == subscribed))) ->
				{error, ?ERR_FORBIDDEN};
			    (Size > MaxSize) ->
				{error, extend_error(?ERR_NOT_ACCEPTABLE, "payload-too-big")};
			    true ->
				NewInfo =
				    insert_item(Info, ItemID,
						Publisher, Payload),
				NewNode = set_node_info(N, NewInfo),
				mnesia:write(NewNode),
				{result, []}
			end;
		    {error, _} = Error ->
			Error
		end
	end,
    case mnesia:transaction(F) of
	{atomic, {error, _} = Error} ->
	    Error;
	{atomic, {result, Res}} ->
	    broadcast_publish_item(Host, Node, ItemID, Payload, jlib:jid_tolower(JID)),
	    {result, Res};
	OtherError ->
	    ?ERROR_MSG("~p", [OtherError]),
	    {error, ?ERR_INTERNAL_SERVER_ERROR}
    end.


delete_item(Host, JID, Node, ItemID, ForceNotify) ->
    Publisher = jlib:jid_tolower(jlib:jid_remove_resource(JID)),
    Table = get_table(Host),
    F = fun() ->
		case mnesia:read({Table, {Host, Node}}) of
		    [N] ->
			Info = get_node_info(N),
			ItemExists = lists:any(fun(I) ->
						       I#item.id == ItemID
					       end, Info#nodeinfo.items),
			Allowed = check_item_publisher(Info, ItemID, Publisher)
			    orelse
			      (get_affiliation(Info, Publisher) == owner),
			if not Allowed ->
				{error, ?ERR_FORBIDDEN};
			   not ItemExists ->
				{error, ?ERR_ITEM_NOT_FOUND};
			   true ->
				NewInfo =
				    remove_item(Info, ItemID),
				mnesia:write(
				  set_node_info(N, NewInfo)),
				{result, []}
			end;
		    [] ->
			{error, ?ERR_ITEM_NOT_FOUND}
		end
	end,
    case mnesia:transaction(F) of
	{atomic, {error, _} = Error} ->
	    Error;
	{atomic, {result, Res}} ->
	    broadcast_retract_item(Host, Node, ItemID, ForceNotify),
	    {result, Res};
	_ ->
	    {error, ?ERR_INTERNAL_SERVER_ERROR}
    end.

%% Add pubsub-specific error element
extend_error({xmlelement, "error", Attrs, SubEls}, Error) ->
    {xmlelement, "error", Attrs,
     [{xmlelement, Error, [{"xmlns", ?NS_PUBSUB_ERRORS}], []}
      | SubEls]}.

extend_error({xmlelement, "error", Attrs, SubEls}, unsupported, Feature) ->
    {xmlelement, "error", Attrs,
     [{xmlelement, "unsupported", [{"xmlns", ?NS_PUBSUB_ERRORS},
				   {"feature", Feature}], []}
      | SubEls]}.

subscribe_node(Host, From, JID, Node) ->
    Sender = jlib:jid_tolower(jlib:jid_remove_resource(From)),
    SubscriberJID =
	case jlib:string_to_jid(JID) of
	    error ->
		{"", "", ""};
	    J ->
		J
	end,
    Subscriber = jlib:jid_tolower(SubscriberJID),
    SubscriberWithoutResource = jlib:jid_remove_resource(Subscriber),
    AuthorizedToSubscribe = Sender == SubscriberWithoutResource,
    Table = get_table(Host),
    case catch mnesia:dirty_read({Table, {Host, Node}}) of
	[NodeData] ->
	    NodeInfo = get_node_info(NodeData),
	    AllowSubscriptions = get_node_option(NodeInfo, subscribe),
	    AccessModel = get_node_option(NodeInfo, access_model),
	    AllowedGroups = get_node_option(NodeInfo, access_roster_groups),
	    Affiliation = get_affiliation(NodeInfo, Subscriber),
	    OldSubscription = get_subscription(NodeInfo, Subscriber),
	    CurrentApprover = get_node_option(NodeInfo, current_approver);
	[] ->
	    {AllowSubscriptions,
	     AccessModel,
	     AllowedGroups,
	     Affiliation,
	     OldSubscription,
	     CurrentApprover} = {notfound, notfound, notfound, notfound, notfound, notfound};
	_ ->
	    {AllowSubscriptions,
	     AccessModel,
	     AllowedGroups,
	     Affiliation,
	     OldSubscription,
	     CurrentApprover} = {error, error, error, error, error, error}
    end,
    Subscription = if AllowSubscriptions == notfound ->
			   {error, ?ERR_ITEM_NOT_FOUND};
		      AllowSubscriptions == error ->
			   {error, ?ERR_INTERNAL_SERVER_ERROR};
		      not AuthorizedToSubscribe ->
			   {error, extend_error(?ERR_BAD_REQUEST, "invalid-jid")};
		      not AllowSubscriptions ->
			   {error, extend_error(?ERR_FEATURE_NOT_IMPLEMENTED, unsupported, "subscribe")};
		      OldSubscription == pending ->
			   {error, extend_error(?ERR_NOT_AUTHORIZED, "pending-subscription")};
		      Affiliation == outcast ->
			   {error, ?ERR_FORBIDDEN};
		      AccessModel == open; Affiliation == owner; Affiliation == publisher ->
			   subscribed;
		      AccessModel == authorize ->
			   pending;
		      AccessModel == presence ->
			   %% XXX: this applies only to PEP
			   {OUser, OServer, _} = Host,
			   case has_presence_subscription(OUser, OServer, Subscriber) of
			       true ->
				   subscribed;
			       false ->
				   {error, extend_error(?ERR_NOT_AUTHORIZED, "presence-subscription-required")}
			   end;
		      AccessModel == roster ->
			   %% XXX: this applies only to PEP
			   {OUser, OServer, _} = Host,
			   case is_in_roster_group(OUser, OServer, Subscriber, AllowedGroups) of
			       true ->
				   subscribed;
			       false ->
				   {error, extend_error(?ERR_NOT_AUTHORIZED, "not-in-roster-group")}
			   end;
		      AccessModel == whitelist ->
			    %% Subscribers are added by owner (see set_entities)
			    {error, extend_error(?ERR_NOT_ALLOWED, "closed-node")}
		   end,
    F = fun() ->
  		case mnesia:read({Table, {Host, Node}}) of
  		    [N] ->
			Info = get_node_info(N),
			NewInfo = add_subscriber(Info, Subscriber, Subscription),
			mnesia:write(set_node_info(N, NewInfo)),
			{result, [{xmlelement, "subscription",
				   [{"node", Node},
				    {"jid", jlib:jid_to_string(Subscriber)},
				    {"subscription", 
				     subscription_to_string(Subscription)}],
				   []}],
			 Info}
		end
	end,
    case Subscription of
	{error, _} = Error ->
	    Error;
	_ ->
	    case mnesia:transaction(F) of
		{atomic, {error, _} = Error} ->
		    Error;
 		{atomic, {result, Res, Info}} ->
		    if Subscription == subscribed ->
			    SendLastPublishedItem = get_node_option(Info, send_last_published_item),
			    if SendLastPublishedItem /= never ->
				    send_last_published_item(Subscriber, Host, Node, Info);
				true ->
				    ok
			    end;
		       Subscription == pending ->
			    %% send authorization request to node owner (section 8.6)

			    %% XXX: fix translation
			    Lang = "en",
			    send_authorization_request(Lang, CurrentApprover, Subscriber, Node, Host)
		    end,
		    {result, Res};
		_ ->
		    {error, ?ERR_INTERNAL_SERVER_ERROR}
	    end
    end.

has_presence_subscription(OwnerUser, OwnerServer, {SubscriberUser, SubscriberServer, _}) ->
    {Subscription, _Groups} =
	ejabberd_hooks:run_fold(
	  roster_get_jid_info, OwnerServer,
	  {none, []}, [OwnerUser, OwnerServer, {SubscriberUser, SubscriberServer, ""}]),
    if (Subscription == both) or
       (Subscription == from) ->
	    true;
       true ->
	    false
    end.

is_in_roster_group(OwnerUser, OwnerServer, {SubscriberUser, SubscriberServer, _}, AllowedGroups) ->
    {_Subscription, Groups} =
	ejabberd_hooks:run_fold(
	  roster_get_jid_info, OwnerServer,
	  {none, []}, [OwnerUser, OwnerServer, {SubscriberUser, SubscriberServer, ""}]),
    lists:any(fun(Group) -> lists:member(Group, AllowedGroups) end,
	      Groups).

send_authorization_request(Lang, Approver, Subscriber, Node, Host) ->
    Stanza =
	{xmlelement, "message",
	 [],
	 [{xmlelement, "x", [{"xmlns", ?NS_XDATA},
			     {"type", "form"}],
	   [{xmlelement, "title", [],
	     [{xmlcdata, translate:translate(Lang, "PubSub subscriber request")}]},
	    {xmlelement, "instructions", [],
	     [{xmlcdata, translate:translate(Lang, "Choose whether to approve this entity's subscription.")}]},
	    {xmlelement, "field", [{"var", "FORM_TYPE"}, {"type", "hidden"}],
	     [{xmlelement, "value", [], [{xmlcdata, ?NS_PUBSUB_SUB_AUTH}]}]},
	    {xmlelement, "field", [{"var", "pubsub#node"}, {"type", "text-single"},
				   {"label", translate:translate(Lang, "Node ID")}],
	     [{xmlelement, "value", [], [{xmlcdata, node_to_string(Node)}]}]},
	    {xmlelement, "field", [{"var", "pubsub#subscriber_jid"},
				   {"type", "jid-single"},
				   {"label", translate:translate(Lang, "Subscriber Address")}],
	     [{xmlelement, "value", [], [{xmlcdata, jlib:jid_to_string(Subscriber)}]}]},
	    {xmlelement, "field", [{"var", "pubsub#allow"}, {"type", "boolean"},
				   {"label", translate:translate(Lang, "Allow this JID to subscribe to this pubsub node?")}],
	     [{xmlelement, "value", [], [{xmlcdata, "false"}]}]}]}]},
    ejabberd_router:route(get_sender(Host), Approver, Stanza).

find_authorization_response(Packet) ->
    {xmlelement, _Name, _Attrs, Els} = Packet,
    XData1 = lists:map(fun({xmlelement, "x", XAttrs, _} = XEl) ->
			       case xml:get_attr_s("xmlns", XAttrs) of
				   ?NS_XDATA ->
				       case xml:get_attr_s("type", XAttrs) of
					   "cancel" ->
					       none;
					   _ ->
					       jlib:parse_xdata_submit(XEl)
				       end;
				   _ ->
				       none
			       end;
			  (_) ->
			       none
		       end, xml:remove_cdata(Els)),
    XData = lists:filter(fun(E) -> E /= none end, XData1),
    case XData of
	[invalid] -> invalid;
	[] -> none;
	[XFields] when is_list(XFields) ->
	    case lists:keysearch("FORM_TYPE", 1, XFields) of
		{value, {_, ?NS_PUBSUB_SUB_AUTH}} ->
		    XFields;
		_ ->
		    invalid
	    end
    end.

handle_authorization_response(From, To, Host, Packet, XFields) ->
    case {lists:keysearch("pubsub#node", 1, XFields),
	  lists:keysearch("pubsub#subscriber_jid", 1, XFields),
	  lists:keysearch("pubsub#allow", 1, XFields)} of
	{{value, {_, SNode}}, {value, {_, SSubscriber}},
	 {value, {_, SAllow}}} ->
	    Node = case Host of
		       {_, _, _} ->
			   SNode;
		       _ ->
			   string:tokens(SNode, "/")
		   end,
	    Subscriber = jlib:string_to_jid(SSubscriber),
	    Allow = case SAllow of
			"1" -> true;
			"true" -> true;
			_ -> false
		    end,
	    Table = get_table(Host),
	    F = fun() ->
			case mnesia:read({Table, {Host, Node}}) of
			    [N] ->
				Info = get_node_info(N),
				Subscription = get_subscription(Info, Subscriber),
				Approver = get_node_option(N, current_approver),
				IsApprover = jlib:jid_tolower(jlib:jid_remove_resource(From)) ==
				    jlib:jid_tolower(jlib:jid_remove_resource(Approver)),
				if not IsApprover ->
					{error, ?ERR_FORBIDDEN};
				   Subscription /= pending ->
					{error, ?ERR_UNEXPECTED_REQUEST};
				   true ->
					NewSubscription = case Allow of
							      true -> subscribed;
							      false -> none
							  end,
					NewInfo = add_subscriber(Info, Subscriber, NewSubscription),
					mnesia:write(set_node_info(N, NewInfo)),
					NewSubscription
				end;
			    [] ->
				{error, ?ERR_ITEM_NOT_FOUND}
			end
		end,
	    case mnesia:transaction(F) of
		{atomic, {error, Error}} ->
		    ejabberd_router:route(To, From,
					  jlib:make_error_reply(Packet, Error));
		{atomic, NewSubscription} ->
		    %% XXX: notify about subscription state change, section 12.11
		    ok;
		_ ->
		    ejabberd_router:route(To, From,
					  jlib:make_error_reply(Packet, ?ERR_INTERNAL_SERVER_ERROR))
	    end;
	_ ->
	    ejabberd_router:route(To, From,
				  jlib:make_error_reply(Packet, ?ERR_NOT_ACCEPTABLE))
    end.

unsubscribe_node(Host, From, JID, Node) ->
    Sender = jlib:jid_tolower(jlib:jid_remove_resource(From)),
    SubscriberJID =
	case jlib:string_to_jid(JID) of
	    error ->
		{"", "", ""};
	    J ->
		J
	end,
    Subscriber = jlib:jid_tolower(SubscriberJID),
    Table = get_table(Host),
    F = fun() ->
		case mnesia:read({Table, {Host, Node}}) of
		    [N] ->
			Info = get_node_info(N),
			Subscription = get_subscription(Info, Subscriber),
			if
			    Subscription /= none ->
				NewInfo =
				    remove_subscriber(Info, Subscriber),
				mnesia:write(
				  set_node_info(N, NewInfo)),
				{result, []};
			    true ->
				{error, extend_error(?ERR_UNEXPECTED_REQUEST, "not-subscribed")}
			end;
		    [] ->
			{error, ?ERR_ITEM_NOT_FOUND}
		end
	end,
    if
	Sender == Subscriber ->
	    case mnesia:transaction(F) of
		{atomic, {error, _} = Error} ->
		    Error;
		{atomic, {result, Res}} ->
		    {result, Res};
		_ ->
		    {error, ?ERR_INTERNAL_SERVER_ERROR}
	    end;
	true ->
	    {error, ?ERR_FORBIDDEN}
    end.


get_items(Host, JID, Node, SMaxItems) ->
    MaxItems =
	if
	    SMaxItems == "" ->
		?MAXITEMS;
	    true ->
		case catch list_to_integer(SMaxItems) of
		    {'EXIT', _} ->
			{error, ?ERR_BAD_REQUEST};
		    Val ->
			Val
		end
	end,
    Table = get_table(Host),
    case MaxItems of
	{error, _} = Error ->
	    Error;
	_ ->
	    case catch mnesia:dirty_read(Table, {Host, Node}) of
		[N] ->
		    Info = get_node_info(N),
		    Items = lists:sublist(Info#nodeinfo.items, MaxItems),
		    ItemsEls =
			lists:map(
			  fun(#item{id = ItemID,
				    payload = Payload}) ->
				  ItemAttrs = case ItemID of
						  "" -> [];
						  _ -> [{"id", ItemID}]
					      end,
				  {xmlelement, "item", ItemAttrs, Payload}
			  end, Items),
		    {result, [{xmlelement, "pubsub",
			       [{"xmlns", ?NS_PUBSUB}],
			       [{xmlelement, "items",
				 [{"node", node_to_string(Node)}],
				 ItemsEls}]}]};
		_ ->
		    {error, ?ERR_ITEM_NOT_FOUND}
	    end
    end.


delete_node(Host, JID, Node) ->
    Owner = jlib:jid_tolower(jlib:jid_remove_resource(JID)),
    Table = get_table(Host),
    F = fun() ->
		case mnesia:read({Table, {Host, Node}}) of
		    [N1] ->
			Info = get_node_info(N1),
			case get_affiliation(Info, Owner) of
			    owner ->
				%% PEP nodes are not hierarchical, so removal is easier.
				case Table of
				    pep_node ->
					mnesia:delete({Table, {Host, Node}}),
					{removed, [{N1, Info}]};
				    pubsub_node ->
					%% TODO: don't iterate over entire table
					Removed =
					    mnesia:foldl(
					      fun(#pubsub_node{host_node = {_, N},
							       info = NInfo}, Acc) ->
						      case lists:prefix(Node, N) of
							  true ->
							      [{N, NInfo} | Acc];
							  _ ->
							      Acc
						      end
					      end, [], pubsub_node),
					lists:foreach(
					  fun({N, _}) ->
						  mnesia:delete({pubsub_node, {Host, N}})
					  end, Removed),
					{removed, Removed}
				end;
			    _ ->
				{error, ?ERR_FORBIDDEN}
			end;
		    [] ->
			{error, ?ERR_ITEM_NOT_FOUND}
		end
	end,
    case mnesia:transaction(F) of
	{atomic, {error, _} = Error} ->
	    Error;
	{atomic, {removed, Removed}} ->
	    broadcast_removed_node(Host, Removed),
	    case Table of
		pubsub_node ->
		    broadcast_retract_item(
		      Host, ["pubsub", "nodes"], node_to_string(Node), false);
		_ ->
		    ok
	    end,
	    {result, []};
	_ ->
	    {error, ?ERR_INTERNAL_SERVER_ERROR}
    end.


purge_node(Host, JID, Node) ->
    Owner = jlib:jid_tolower(jlib:jid_remove_resource(JID)),
    Table = get_table(Host),
    F = fun() ->
		case mnesia:read({Table, {Host, Node}}) of
		    [N] ->
			Info = get_node_info(N),
			case get_affiliation(Info, Owner) of
			    owner ->
				NewInfo = Info#nodeinfo{items = []},
				mnesia:write(set_node_info(N, NewInfo)),
				{result, []};
			    _ ->
				{error, ?ERR_FORBIDDEN}
			end;
		    [] ->
			{error, ?ERR_ITEM_NOT_FOUND}
		end
	end,
    case mnesia:transaction(F) of
	{atomic, {error, _} = Error} ->
	    Error;
	{atomic, {result, Res}} ->
	    broadcast_purge_node(Host, Node),
	    {result, Res};
	_ ->
	    {error, ?ERR_INTERNAL_SERVER_ERROR}
    end.


owner_get_subscriptions(Host, OJID, Node) ->
    Owner = jlib:jid_tolower(jlib:jid_remove_resource(OJID)),
    Table = get_table(Host),
    case catch mnesia:dirty_read(Table, {Host, Node}) of
	[N] ->
	    Info = get_node_info(N),
	    case get_affiliation(Info, Owner) of
		owner ->
		    Entities = Info#nodeinfo.entities,
		    EntitiesEls =
			?DICT:fold(
			  fun(JID,
			      #entity{subscription = Subscription},
			      Acc) ->
				  case Subscription of
				      none ->
					  Acc;
				      _ ->
					  [{xmlelement, "subscription",
					    [{"jid", jlib:jid_to_string(JID)},
					     {"subscription",
					      subscription_to_string(Subscription)}],
					    []} | Acc]
				  end
			  end, [], Entities),
		    {result, [{xmlelement, "pubsub",
			       [{"xmlns", ?NS_PUBSUB_OWNER}],
			       [{xmlelement, "subscriptions",
				 [{"node", node_to_string(Node)}],
				 EntitiesEls}]}]};
		_ ->
		    {error, ?ERR_FORBIDDEN}
	    end;
	_ ->
	    {error, ?ERR_ITEM_NOT_FOUND}
    end.


owner_set_subscriptions(Host, OJID, Node, EntitiesEls) ->
    %% XXX: not updated for PEP and new pubsub revision
    Owner = jlib:jid_tolower(jlib:jid_remove_resource(OJID)),
    Entities =
	lists:foldl(
	  fun(El, Acc) ->
		  case Acc of
		      error ->
			  error;
		      _ ->
			  case El of
			      {xmlelement, "entity", Attrs, _} ->
				  JID = jlib:string_to_jid(
					  xml:get_attr_s("jid", Attrs)),
				  Affiliation =
				      case xml:get_attr_s("affiliation",
							  Attrs) of
					  "owner" -> owner;
					  "publisher" -> publisher;
					  "outcast" -> outcast;
					  "none" -> none;
					  _ -> false
				      end,
				  Subscription =
				      case xml:get_attr_s("subscription",
							  Attrs) of
					  "subscribed" -> subscribed;
					  "pending" -> pending;
					  "unconfigured" -> unconfigured;
					  "none" -> none;
					  _ -> false
				      end,
				  if
				      (JID == error) or
				      (Affiliation == false) or
				      (Subscription == false) ->
					  error;
				      true ->
					  [{jlib:jid_tolower(JID),
					    #entity{
					      affiliation = Affiliation,
					      subscription = Subscription}} |
					   Acc]
				  end
			  end
		  end
	  end, [], EntitiesEls),
    case Entities of
	error ->
	    {error, ?ERR_BAD_REQUEST};
	_ ->
	    F = fun() ->
			case mnesia:read({pubsub_node, {Host, Node}}) of
			    [#pubsub_node{info = Info} = N] ->
				case get_affiliation(Info, Owner) of
				    owner ->
					NewInfo =
					    set_info_entities(Info, Entities),
					mnesia:write(
					  N#pubsub_node{info = NewInfo}),
					{result, []};
				    _ ->
					{error, ?ERR_NOT_ALLOWED}
				end;
			    [] ->
				{error, ?ERR_ITEM_NOT_FOUND}
			end
		end,
	    case mnesia:transaction(F) of
		{atomic, {error, _} = Error} ->
		    Error;
		{atomic, {result, _}} ->
		    {result, []};
		_ ->
		    {error, ?ERR_INTERNAL_SERVER_ERROR}
	    end
    end.

owner_get_affiliations(Host, OJID, Node) ->
    Owner = jlib:jid_tolower(jlib:jid_remove_resource(OJID)),
    Table = get_table(Host),
    case catch mnesia:dirty_read(Table, {Host, Node}) of
	[N] ->
	    Info = get_node_info(N),
	    case get_affiliation(Info, Owner) of
		owner ->
		    Entities = Info#nodeinfo.entities,
		    EntitiesEls =
			?DICT:fold(
			  fun(JID,
			      #entity{affiliation = Affiliation},
			      Acc) ->
				  case Affiliation of
				      none ->
					  Acc;
				      _ ->
					  [{xmlelement, "affiliation",
					    [{"jid", jlib:jid_to_string(JID)},
					     {"affiliation",
					      affiliation_to_string(Affiliation)}],
					    []} | Acc]
				  end
			  end, [], Entities),
		    {result, [{xmlelement, "pubsub",
			       [{"xmlns", ?NS_PUBSUB_OWNER}],
			       [{xmlelement, "affiliations",
				 [{"node", node_to_string(Node)}],
				 EntitiesEls}]}]};
		_ ->
		    {error, ?ERR_FORBIDDEN}
	    end;
	_ ->
	    {error, ?ERR_ITEM_NOT_FOUND}
    end.


owner_set_affiliations(Host, OJID, Node, EntitiesEls) ->
    %% XXX: not updated for PEP and new pubsub revision
    Owner = jlib:jid_tolower(jlib:jid_remove_resource(OJID)),
    Entities =
	lists:foldl(
	  fun(El, Acc) ->
		  case Acc of
		      error ->
			  error;
		      _ ->
			  case El of
			      {xmlelement, "entity", Attrs, _} ->
				  JID = jlib:string_to_jid(
					  xml:get_attr_s("jid", Attrs)),
				  Affiliation =
				      case xml:get_attr_s("affiliation",
							  Attrs) of
					  "owner" -> owner;
					  "publisher" -> publisher;
					  "outcast" -> outcast;
					  "none" -> none;
					  _ -> false
				      end,
				  Subscription =
				      case xml:get_attr_s("subscription",
							  Attrs) of
					  "subscribed" -> subscribed;
					  "pending" -> pending;
					  "unconfigured" -> unconfigured;
					  "none" -> none;
					  _ -> false
				      end,
				  if
				      (JID == error) or
				      (Affiliation == false) or
				      (Subscription == false) ->
					  error;
				      true ->
					  [{jlib:jid_tolower(JID),
					    #entity{
					      affiliation = Affiliation,
					      subscription = Subscription}} |
					   Acc]
				  end
			  end
		  end
	  end, [], EntitiesEls),
    case Entities of
	error ->
	    {error, ?ERR_BAD_REQUEST};
	_ ->
	    F = fun() ->
			case mnesia:read({pubsub_node, {Host, Node}}) of
			    [#pubsub_node{info = Info} = N] ->
				case get_affiliation(Info, Owner) of
				    owner ->
					NewInfo =
					    set_info_entities(Info, Entities),
					mnesia:write(
					  N#pubsub_node{info = NewInfo}),
					{result, []};
				    _ ->
					{error, ?ERR_NOT_ALLOWED}
				end;
			    [] ->
				{error, ?ERR_ITEM_NOT_FOUND}
			end
		end,
	    case mnesia:transaction(F) of
		{atomic, {error, _} = Error} ->
		    Error;
		{atomic, {result, _}} ->
		    {result, []};
		_ ->
		    {error, ?ERR_INTERNAL_SERVER_ERROR}
	    end
    end.


get_affiliations(Host, JID) ->
    LJID = jlib:jid_tolower(jlib:jid_remove_resource(JID)),
    Table = get_table(Host),
    Template = case Table of
		   pubsub_node ->
		       #pubsub_node{_ = '_'};
		   pep_node ->
		       #pep_node{_ = '_'}
	       end,
    case catch mnesia:dirty_select(
		 Table,
		 [{Template,
		   [],
		   ['$_']}]) of
	{'EXIT', _} ->
		 {error, ?ERR_INTERNAL_SERVER_ERROR};
	Nodes ->
		 Entities =
		     lists:flatmap(
		       fun(N) ->
			       Info = get_node_info(N),
			       {H, Node} =
				   case Table of
				       pubsub_node ->
					   N#pubsub_node.host_node;
				       pep_node ->
					   N#pep_node.owner_node
				   end,
			       if Host == H ->
				       Affiliation = get_affiliation(Info, LJID),
				       if Affiliation /= none ->
					       [{xmlelement, "affiliation",
						 [{"node", node_to_string(Node)},
						  {"affiliation",
						   affiliation_to_string(Affiliation)}],
						 []}];
					   true ->
					       []
				       end;
				  true ->
				       []
			       end
		       end, 
		       Nodes),
		 {result, [{xmlelement, "pubsub",
			    [{"xmlns", ?NS_PUBSUB}],
			    [{xmlelement, "affiliations", [],
			      Entities}]}]}
	 end.

get_subscriptions(Host, JID) ->
    LJID = jlib:jid_tolower(jlib:jid_remove_resource(JID)),
    Table = get_table(Host),
    Template = case Table of
		   pubsub_node ->
		       #pubsub_node{_ = '_'};
		   pep_node ->
		       #pep_node{_ = '_'}
	       end,
    case catch mnesia:dirty_select(
		 Table,
		 [{Template,
		   [],
		   ['$_']}]) of
	{'EXIT', _} ->
		 {error, ?ERR_INTERNAL_SERVER_ERROR};
	Nodes ->
		 Entities =
		     lists:flatmap(
		       fun(N) ->
			       Info = get_node_info(N),
			       {H, Node} =
				   case Table of
				       pubsub_node ->
					   N#pubsub_node.host_node;
				       pep_node ->
					   N#pep_node.owner_node
				   end,
			       if Host == H ->
				       Subscription = get_subscription(Info, LJID),
				       if Subscription /= none ->
					       [{xmlelement, "subscription",
						 [{"node", node_to_string(Node)},
						  {"jid", jlib:jid_to_string(LJID)}, %XXX: full JID?
						  {"subscription",
						   subscription_to_string(Subscription)}],
						 []}];
					   true ->
					       []
				       end;
				  true ->
				       []
			       end
		       end, 
		       Nodes),
		 {result, [{xmlelement, "pubsub",
			    [{"xmlns", ?NS_PUBSUB}],
			    [{xmlelement, "subscriptions", [],
			      Entities}]}]}
	 end.




get_affiliation(#nodeinfo{entities = Entities}, JID) ->
    LJID = jlib:jid_tolower(jlib:jid_remove_resource(JID)),
    case ?DICT:find(LJID, Entities) of
	{ok, #entity{affiliation = Affiliation}} ->
	    Affiliation;
	_ ->
	    none
    end.

get_subscription(#nodeinfo{entities = Entities}, JID) ->
    LJID = jlib:jid_tolower(jlib:jid_remove_resource(JID)),
    case ?DICT:find(LJID, Entities) of
	{ok, #entity{subscription = Subscription}} ->
	    Subscription;
	_ ->
	    none
    end.

affiliation_to_string(Affiliation) ->
    case Affiliation of
	owner -> "owner";
	publisher -> "publisher";
	outcast -> "outcast";
	_ -> "none"
    end.

subscription_to_string(Subscription) ->
    case Subscription of
	subscribed -> "subscribed";
	pending -> "pending";
	unconfigured -> "unconfigured";
	_ -> "none"
    end.


check_create_permission(Host, Node, Owner, ServerHost, Access) ->
	#jid{luser = User, lserver = Server, lresource = Resource} = Owner,
    case acl:match_rule(ServerHost, Access, {User, Server, Resource}) of
    allow ->
    	if Server == Host ->
	    	true;
		true ->
	    	case Node of
			["home", Server, User | _] ->
		    	true;
			_ ->
			    false
		    end
	    end;
	_ ->
	    case Owner of
		?MYJID ->
		    true;
		_ ->
		    false
	    end
    end.

insert_item(Info, ItemID, Publisher, Payload) ->
    Items = Info#nodeinfo.items,
    Items1 = lists:filter(fun(I) ->
				  I#item.id /= ItemID
			  end, Items),
    Items2 = [#item{id = ItemID, publisher = Publisher, payload = Payload} |
	      Items1],
    Items3 = lists:sublist(Items2, get_max_items(Info)),
    Info#nodeinfo{items = Items3}.

remove_item(Info, ItemID) ->
    Items = Info#nodeinfo.items,
    Items1 = lists:filter(fun(I) ->
				  I#item.id /= ItemID
			  end, Items),
    Info#nodeinfo{items = Items1}.

check_item_publisher(Info, ItemID, Publisher) ->
    Items = Info#nodeinfo.items,
    case lists:keysearch(ItemID, #item.id, Items) of
	{value, #item{publisher = Publisher}} ->
	    true;
	_ ->
	    false
    end.

add_subscriber(Info, Subscriber, Subscription) ->
    Entities = Info#nodeinfo.entities,
    case ?DICT:find(Subscriber, Entities) of
	{ok, Entity} ->
	    Info#nodeinfo{
	      entities = ?DICT:store(Subscriber,
				     Entity#entity{subscription = Subscription},
				     Entities)};
	_ ->
	    Info#nodeinfo{
	      entities = ?DICT:store(Subscriber,
				     #entity{subscription = Subscription},
				     Entities)}
    end.

remove_subscriber(Info, Subscriber) ->
    Entities = Info#nodeinfo.entities,
    case ?DICT:find(Subscriber, Entities) of
	{ok, #entity{affiliation = none}} ->
	    Info#nodeinfo{
	      entities = ?DICT:erase(Subscriber, Entities)};
	{ok, Entity} ->
	    Info#nodeinfo{
	      entities = ?DICT:store(Subscriber,
				     Entity#entity{subscription = none},
				     Entities)};
	_ ->
	    Info
    end.


set_info_entities(Info, Entities) ->
    NewEntities =
	lists:foldl(
	  fun({JID, Ent}, Es) ->
		  case Ent of
		      #entity{affiliation = none, subscription = none} ->
			  ?DICT:erase(JID, Es);
		      _ ->
			  ?DICT:store(JID, Ent, Es)
		  end
	  end, Info#nodeinfo.entities, Entities),
    Info#nodeinfo{entities = NewEntities}.

send_last_published_item(Subscriber, Host, Node, Info) ->
    case Info#nodeinfo.items of
	[] ->
	    %% No published items - can't send anything.
	    ok;
	[#item{id = ItemID, payload = Payload} | _] ->
	    %% At least one item - send the last one.
	    ItemAttrs = case ItemID of
			    "" -> [];
			    _ -> [{"id", ItemID}]
			end,
	    ItemsEl = {xmlelement, "item",
		       ItemAttrs, Payload},
	    Stanza =
		{xmlelement, "message",
		 [],
		 [{xmlelement, "event",
		   [{"xmlns", ?NS_PUBSUB_EVENT}],
		   [{xmlelement, "items",
		     [{"node", node_to_string(Node)}],
	     [ItemsEl]}]}]},
	    ejabberd_router:route(
	      get_sender(Host), jlib:make_jid(Subscriber), Stanza)
    end.

%% broadcast Stanza to all contacts of the user that are advertising
%% interest in this kind of Node.
broadcast_by_caps({LUser, LServer, LResource}, Node, Stanza) ->
    ?DEBUG("looking for pid of ~p@~p/~p", 
	   [LUser, LServer, LResource]),
    %% We need to know the resource, so we can ask for presence data.
    LResource1 = case LResource of
		     "" ->
			 %% If we don't know the resource, just pick one.
			 case ejabberd_sm:get_user_resources(LUser, LServer) of
			     [R|_] ->
				 R;
			     %% But maybe the user is offline.
			     [] ->
				 ?ERROR_MSG("~p@~p is offline; can't deliver ~p to contacts",
					    [LUser, LServer, Stanza]),
				 ""
			 end;
		     R ->
			 R
		 end,
    %% But we don't fake a resource for the sender address.
    Sender = jlib:make_jid(LUser, LServer, LResource),
    case ejabberd_sm:get_session_pid(LUser, LServer, LResource1) of
	C2SPid when is_pid(C2SPid) ->
	    ?DEBUG("found it", []),
	    case catch ejabberd_c2s:get_subscribed_and_online(C2SPid) of
		ContactsWithCaps when is_list(ContactsWithCaps) ->
		    ?DEBUG("found contacts with caps: ~p", [ContactsWithCaps]),
		    LookingFor = Node++"+notify",
		    %% We have a list of the form [{JID, Caps}].
		    lists:foreach(
		      fun({JID, Caps}) ->
			      case catch mod_caps:get_features(?MYNAME, Caps) of
				  Features when is_list(Features) ->
				      case lists:member(LookingFor, Features) of
					  true ->
					      ejabberd_router:route(
						Sender, jlib:make_jid(JID), Stanza);
					  _ ->
					      ok
				      end;
				  _ ->
				      %% couldn't get entity capabilities.  
				      %% nothing to do about that...
				      ok
			      end
		      end, ContactsWithCaps);
		_ ->
		    ok
	    end;
	_ ->
	    ok
    end.


broadcast_publish_item(Host, Node, ItemID, Payload, From) ->
    ?DEBUG("broadcasting for ~p / ~p", [Host, Node]),
    Table = get_table(Host),
    Sender = get_sender(Host),
    case catch mnesia:dirty_read(Table, {Host, Node}) of
	[N] ->
	    Info = get_node_info(N),

	    ItemAttrs = case ItemID of
			    "" -> [];
			    _ -> [{"id", ItemID}]
			end,
	    Content = case get_node_option(
			     Info, deliver_payloads) of
			  true ->
			      Payload;
			  false ->
			      []
		      end,
	    Stanza =
		{xmlelement, "message", [],
		 [{xmlelement, "event",
		   [{"xmlns", ?NS_PUBSUB_EVENT}],
		   [{xmlelement, "items",
		     [{"node", node_to_string(Node)}],
		     [{xmlelement, "item",
		       ItemAttrs,
		       Content}]}]}]},

	    ?DICT:fold(
	       fun(JID, #entity{subscription = Subscription}, _) ->
		       Resources = get_recipient_resources(Host, JID, Info),
		       ?DEBUG("subscriber ~p: delivering to resources ~p", [JID, Resources]),
		       if
			   Subscription /= none,
			   Subscription /= pending,
			   Resources /= [] ->
			       TheJID = jlib:make_jid(JID),
			       lists:foreach(fun(Resource) ->
						     FullJID = jlib:jid_replace_resource(TheJID, Resource),
						     ejabberd_router:route(
						       Sender, FullJID, Stanza)
					     end, Resources);
			   true ->
			       ok
		       end
	       end, ok, Info#nodeinfo.entities),

	    case Info#nodeinfo.options of
		[{defaults, pep_node} | _] ->
		    %% If this is PEP, we want to generate
		    %% notifications based on entity capabilities as
		    %% well.
		    broadcast_by_caps(From, Node, Stanza);
		_ ->
		    ok
	    end;
	_ ->
	    false
    end.


broadcast_retract_item(Host, Node, ItemID, ForceNotify) ->
    Table = get_table(Host),
    Sender = get_sender(Host),
    case catch mnesia:dirty_read(Table, {Host, Node}) of
	[N] ->
	    Info = get_node_info(N),
	    case ForceNotify orelse get_node_option(Info, notify_retract) of
		true ->
		    ItemAttrs = case ItemID of
				    "" -> [];
				    _ -> [{"id", ItemID}]
				end,
		    Stanza =
			{xmlelement, "message", [],
			 [{xmlelement, "event",
			   [{"xmlns", ?NS_PUBSUB_EVENT}],
			   [{xmlelement, "items",
			     [{"node", node_to_string(Node)}],
			     [{xmlelement, "retract",
			       ItemAttrs, []}]}]}]},
		    ?DICT:fold(
		       fun(JID, #entity{subscription = Subscription}, _) ->
			       if 
				   (Subscription /= none) and
				   (Subscription /= pending) ->
				       ejabberd_router:route(
					 Sender, jlib:make_jid(JID), Stanza);
				   true ->
				       ok
			       end
		       end, ok, Info#nodeinfo.entities),

		    case Info#nodeinfo.options of
			[{defaults, pep_node} | _] ->
			    %% If this is PEP, we want to generate
			    %% notifications based on entity capabilities as
			    %% well.
			    broadcast_by_caps(Host, Node, Stanza);
			_ ->
			    ok
		    end;

		false ->
		    ok
	    end;
	_ ->
	    false
    end.

broadcast_purge_node(Host, Node) ->
    Table = get_table(Host),
    Sender = get_sender(Host),
    case catch mnesia:dirty_read(Table, {Host, Node}) of
	[N] ->
	    Info = get_node_info(N),
	    case get_node_option(Info, notify_retract) of
		true ->
		    Stanza =
			{xmlelement, "message", [],
			 [{xmlelement, "event",
			   [{"xmlns", ?NS_PUBSUB_EVENT}],
			   [{xmlelement, "purge",
			     [{"node", node_to_string(Node)}],
			     []}]}]},
		    ?DICT:fold(
		       fun(JID, #entity{subscription = Subscription}, _) ->
			       if 
				   (Subscription /= none) and
				   (Subscription /= pending) ->
				       ejabberd_router:route(
					 Sender, jlib:make_jid(JID), Stanza);
				   true ->
				       ok
			       end
		       end, ok, Info#nodeinfo.entities),

		    case Info#nodeinfo.options of
			[{defaults, pep_node} | _] ->
			    %% If this is PEP, we want to generate
			    %% notifications based on entity capabilities as
			    %% well.
			    broadcast_by_caps(Host, Node, Stanza);
			_ ->
			    ok
		    end;

		false ->
		    ok
	    end;
	_ ->
	    false
    end.


broadcast_removed_node(Host, Removed) ->
    lists:foreach(
      fun({NodeData, Info}) ->
	      Node = get_node_name(NodeData),
	      case get_node_option(Info, notify_delete) of
		  true ->
		      Entities = Info#nodeinfo.entities,
		      Stanza =
			  {xmlelement, "message", [],
			   [{xmlelement, "event",
			     [{"xmlns", ?NS_PUBSUB_EVENT}],
			     [{xmlelement, "delete",
			       [{"node", node_to_string(Node)}],
			       []}]}]},
		      ?DICT:fold(
			 fun(JID, #entity{subscription = Subscription}, _) ->
				 if 
				     (Subscription /= none) and
				     (Subscription /= pending) ->
					 ejabberd_router:route(
					   get_sender(Host), jlib:make_jid(JID), Stanza);
				     true ->
					 ok
				 end
			 end, ok, Entities),

		    case Info#nodeinfo.options of
			[{defaults, pep_node} | _] ->
			    %% If this is PEP, we want to generate
			    %% notifications based on entity capabilities as
			    %% well.
			    broadcast_by_caps(Host, Node, Stanza);
			_ ->
			    ok
		    end;

		  false ->
		      ok
	      end
      end, Removed).


broadcast_config_notification(Host, Node, Lang) ->
    Table = get_table(Host),
    case catch mnesia:dirty_read(Table, {Host, Node}) of
	[N] ->
	    Info = get_node_info(N),
	    case get_node_option(Info, notify_config) of
		true ->
		    Fields = get_node_config_xfields(
			       Node, Info, Lang),
		    Content = case get_node_option(
				     Info, deliver_payloads) of
				  true ->
				      [{xmlelement, "x",
					[{"xmlns", ?NS_XDATA},
					 {"type", "result"}],
					Fields}];
				  false ->
				      []
			      end,
		    Stanza =
			{xmlelement, "message", [],
			 [{xmlelement, "event",
			   [{"xmlns", ?NS_PUBSUB_EVENT}],
			   [{xmlelement, "configuration",
			     [{"node", node_to_string(Node)}],
			     Content}]}]},
		    ?DICT:fold(
		       fun(JID, #entity{subscription = Subscription}, _) ->
			       Resources = get_recipient_resources(Host, JID, Info),
			       if
				   Subscription /= none,
				   Subscription /= pending,
				   Resources /= [] ->
				       TheJID = jlib:make_jid(JID),
				       lists:foreach(fun(Resource) ->
							     FullJID = jlib:jid_replace_resource(TheJID, Resource),
							     ejabberd_router:route(
							       get_sender(Host), FullJID, Stanza)
						     end, Resources);
				   true ->
				       ok
			       end
		       end, ok, Info#nodeinfo.entities),

		    case Info#nodeinfo.options of
			[{defaults, pep_node} | _] ->
			    %% If this is PEP, we want to generate
			    %% notifications based on entity capabilities as
			    %% well.
			    broadcast_by_caps(Host, Node, Stanza);
			_ ->
			    ok
		    end;

		false ->
		    ok
	    end;
	_ ->
	    false
    end.

get_recipient_resources(Host, JID, Info) ->
    %% Return a list of resources that are supposed to receive event
    %% notifications.  An empty string in that list means a bare JID.
    case get_node_option(Info, presence_based_delivery) of
	false ->
	    [""];
	true ->
	    To = case Host of
		     {_, _, _} ->
			 Host;
		     _ ->
			 {"", Host, ""}
		 end,
	    Resources = get_present_resources(To, JID),
	    %% Here, there is a difference between JEP-0060 and
	    %% JEP-0163.  JEP-0060, section 12.1, says that the
	    %% service should not attempt to guess the correct
	    %% resource.  JEP-0163, section 7.1.1.2, says that the
	    %% service must send a notification to each resource.
	    case Info#nodeinfo.options of
		[{defaults, pep_node} | _] ->
		    Resources;
		_ ->
		    %% That means, if noone is online, nothing is
		    %% sent.  If someone is online, send one
		    %% notification.
		    case Resources of
			[] ->
			    [];
			_ ->
			    [""]
		    end
	    end
    end.



iq_pubsub_owner(Host, From, Type, Lang, SubEl) ->
    {xmlelement, _, _, SubEls} = SubEl,
    case xml:remove_cdata(SubEls) of
	[{xmlelement, Name, Attrs, Els}] ->
	    %% For PEP, there is no node hierarchy.
	    Node = case Host of
		       {_, _, _} ->
			    xml:get_attr_s("node", Attrs);
		       _ ->
			   SNode = xml:get_attr_s("node", Attrs),
			   string:tokens(SNode, "/")
		   end,
	    case {Type, Name} of
		{get, "configure"} ->
		    get_node_config(Host, From, Node, Lang);
		{set, "configure"} ->
		    set_node_config(Host, From, Node, Els, Lang);
		{get, "default"} ->
		    Fields = get_node_config_xfields("", 
						     #nodeinfo{options = [{defaults, get_table(Host)}]}
						     , Lang),
		    {result, [{xmlelement, "pubsub",
			       [{"xmlns", ?NS_PUBSUB_OWNER}],
			       [{xmlelement, "default", [],
				 [{xmlelement, "x", [{"xmlns", ?NS_XDATA},
						     {"type", "form"}],
				   Fields}]}]}]};
		{set, "delete"} ->
		    delete_node(Host, From, Node);
		{set, "purge"} ->
		    purge_node(Host, From, Node);
		{get, "subscriptions"} ->
		    owner_get_subscriptions(Host, From, Node);
		{set, "subscriptions"} ->
		    owner_set_subscriptions(Host, From, Node, xml:remove_cdata(Els));
		{get, "affiliations"} ->
		    owner_get_affiliations(Host, From, Node);
		{set, "affiliations"} ->
		    owner_set_affiliations(Host, From, Node, xml:remove_cdata(Els));
		_ ->
		    {error, ?ERR_FEATURE_NOT_IMPLEMENTED}
	    end;
	_ ->
	    {error, ?ERR_BAD_REQUEST}
    end.

get_node_config(Host, From, Node, Lang) ->
    Table = get_table(Host),
    case catch mnesia:dirty_read(Table, {Host, Node}) of
	[N] ->
	    Info = get_node_info(N),
	    case get_affiliation(Info, From) of
		owner ->
		    Fields = get_node_config_xfields(Node, Info, Lang),
		    {result, [{xmlelement, "pubsub",
			       [{"xmlns", ?NS_PUBSUB_OWNER}],
			       [{xmlelement, "configure",
				 [{"node", node_to_string(Node)}],
				 [{xmlelement, "x", [{"xmlns", ?NS_XDATA},
						     {"type", "form"}],
				   Fields}]}]}]};
		_ ->
		    {error, ?ERR_FORBIDDEN}
	    end;
	_ ->
	    {error, ?ERR_ITEM_NOT_FOUND}
    end.

% TODO: move to jlib.hrl
-define(NS_PUBSUB_NODE_CONFIG, "http://jabber.org/protocol/pubsub#node_config").

-define(BOOL_CONFIG_FIELD(Label, Var),
	?BOOLXFIELD(Label, "pubsub#" ++ atom_to_list(Var),
		    get_node_option(Info, Var))).

-define(STRING_CONFIG_FIELD(Label, Var),
	?STRINGXFIELD(Label, "pubsub#" ++ atom_to_list(Var),
		      get_node_option(Info, Var))).

-define(INTEGER_CONFIG_FIELD(Label, Var),
	?STRINGXFIELD(Label, "pubsub#" ++ atom_to_list(Var),
		      integer_to_list(get_node_option(Info, Var)))).

-define(JLIST_CONFIG_FIELD(Label, Var, Opts),
	?LISTXFIELD(Label, "pubsub#" ++ atom_to_list(Var),
		    jlib:jid_to_string(get_node_option(Info, Var)),
		    [jlib:jid_to_string(O) || O <- Opts])).

-define(ALIST_CONFIG_FIELD(Label, Var, Opts),
	?LISTXFIELD(Label, "pubsub#" ++ atom_to_list(Var),
		    atom_to_list(get_node_option(Info, Var)),
		    [atom_to_list(O) || O <- Opts])).


-define(DEFAULT_PUBSUB_OPTIONS,
	[{deliver_payloads, true},
	 {notify_config, false},
	 {notify_delete, false},
	 {notify_retract, true},
	 {persist_items, true},
	 {max_items, ?MAXITEMS div 2},
	 {subscribe, true},
	 {access_model, open},
	 {access_roster_groups, []},
	 {publish_model, publishers},
	 {max_payload_size, ?MAX_PAYLOAD_SIZE},
	 {send_last_published_item, never},
	 {presence_based_delivery, false}]).

-define(DEFAULT_PEP_OPTIONS,
	[{deliver_payloads, true},
	 {notify_config, false},
	 {notify_delete, false},
	 {notify_retract, false},
	 {persist_items, false},
	 {max_items, ?MAXITEMS div 2},
	 {subscribe, true},
	 {access_model, presence},
	 {access_roster_groups, []},
	 {publish_model, publishers},
	 {max_payload_size, ?MAX_PAYLOAD_SIZE},
	 {send_last_published_item, on_sub_and_presence},
	 {presence_based_delivery, true}]).

get_node_option(Info, current_approver) ->
    Default = case get_owners_jids(Info) of
		  [FirstOwner|_] -> FirstOwner;
		  _ -> {"","",""}
	      end,
    Options = Info#nodeinfo.options,
    element(
      2, element(2, lists:keysearch(
		      current_approver, 1,
		      Options ++ [{current_approver, Default}])));
get_node_option(#nodeinfo{options = Options}, Var) ->
    %% At this level, it's hard to know which set of defaults to
    %% apply.  Therefore, all newly created nodes have an extra
    %% "defaults" field.  We assume that all nodes created before this
    %% change are pubsub nodes.
    {Defaults, Opts} = case Options of
			   [{defaults, pubsub_node} | Tail] ->
			       {?DEFAULT_PUBSUB_OPTIONS, Tail};
			   [{defaults, pep_node} | Tail] ->
			       {?DEFAULT_PEP_OPTIONS, Tail};
			   _ ->
			       {?DEFAULT_PUBSUB_OPTIONS, Options}
		       end,
    element(
      2, element(2, lists:keysearch(Var, 1, Opts ++ Defaults))).

get_max_items(Info) ->
    case get_node_option(Info, persist_items) of
	true ->
	    get_node_option(Info, max_items);
	false ->
	    case get_node_option(Info, send_last_published_item) of
		never ->
		    0;
		_ ->
		    1
	    end
    end.

get_owners_jids(Info) ->
    Entities = Info#nodeinfo.entities,
    Owners =
	?DICT:fold(
	   fun(JID,
	       #entity{affiliation = Affiliation},
	       Acc) ->
		   case Affiliation of
		       owner ->
			   [JID | Acc];
		       _ ->
			   Acc
		   end
	   end, [], Entities),
    lists:sort(Owners).


get_node_config_xfields(_Node, Info, Lang) ->
    Type = case Info#nodeinfo.options of
	       [{defaults, D} | _] -> D;
	       _ -> pubsub_node
	   end,
    [?XFIELD("hidden", "", "FORM_TYPE", ?NS_PUBSUB_NODE_CONFIG),
     ?BOOL_CONFIG_FIELD("Deliver payloads with event notifications", deliver_payloads),
     ?BOOL_CONFIG_FIELD("Notify subscribers when the node configuration changes", notify_config),
     ?BOOL_CONFIG_FIELD("Notify subscribers when the node is deleted", notify_delete),
     ?BOOL_CONFIG_FIELD("Notify subscribers when items are removed from the node", notify_retract),
     ?BOOL_CONFIG_FIELD("Persist items to storage", persist_items),
     ?INTEGER_CONFIG_FIELD("Max # of items to persist", max_items),
     ?BOOL_CONFIG_FIELD("Whether to allow subscriptions", subscribe),
     ?ALIST_CONFIG_FIELD("Specify the access model", access_model,
			 [open, whitelist] ++
			 case Type of
			     pep_node -> [presence, roster];
			     pubsub_node -> [authorize]
			 end),
     %% XXX: change to list-multi, include current roster groups as options
     {xmlelement, "field", [{"type", "text-multi"},
			    {"label", translate:translate(Lang, "Roster groups that may subscribe (if access model is roster)")},
			    {"var", "pubsub#access_roster_groups"}],
      [{xmlelement, "value", [], [{xmlcdata, Value}]} ||
	  Value <- get_node_option(Info, access_roster_groups)]},
     ?ALIST_CONFIG_FIELD("Specify the publisher model", publish_model,
			 [publishers, subscribers, open]),
     ?INTEGER_CONFIG_FIELD("Max payload size in bytes", max_payload_size),
     %% XXX: fix labels for options
     ?ALIST_CONFIG_FIELD("When to send the last published item", send_last_published_item,
			 [never, on_sub, on_sub_and_presence]),
     ?BOOL_CONFIG_FIELD("Only deliver notifications to available users", presence_based_delivery),
     ?JLIST_CONFIG_FIELD("Specify the current subscription approver", current_approver,
			 get_owners_jids(Info))
    ].


set_node_config(Host, From, Node, Els, Lang) ->
    Table = get_table(Host),
    case catch mnesia:dirty_read(Table, {Host, Node}) of
	[N] ->
	    Info = get_node_info(N),
	    case get_affiliation(Info, From) of
		owner ->
		    case xml:remove_cdata(Els) of
			[{xmlelement, "x", _Attrs1, _Els1} = XEl] ->
			    case {xml:get_tag_attr_s("xmlns", XEl),
				  xml:get_tag_attr_s("type", XEl)} of
				{?NS_XDATA, "cancel"} ->
				    {result, []};
				{?NS_XDATA, "submit"} ->
				    CurOpts = Info#nodeinfo.options,
				    set_node_config1(
				      Host, From, Node, XEl, CurOpts, Lang);
				_ ->
				    {error, ?ERR_BAD_REQUEST}
			    end;
			_ ->
			    {error, ?ERR_BAD_REQUEST}
		    end;
		_ ->
		    {error, ?ERR_FORBIDDEN}
	    end;
	_ ->
	    {error, ?ERR_ITEM_NOT_FOUND}
    end.


set_node_config1(Host, _From, Node, XEl, CurOpts, Lang) ->
    XData = jlib:parse_xdata_submit(XEl),
    case XData of
	invalid ->
	    {error, ?ERR_BAD_REQUEST};
	_ ->
	    case set_xoption(XData, CurOpts) of
		NewOpts when is_list(NewOpts) ->
		    change_node_opts(Host, NewOpts, Node, Lang);
		Err ->
		    Err
	    end
    end.

add_opt(Key, Value, Opts) ->
    Opts1 = lists:keydelete(Key, 1, Opts),
    [{Key, Value} | Opts1].


-define(SET_BOOL_XOPT(Opt, Val),
	BoolVal = case Val of
		      "0" -> false;
		      "1" -> true;
		      "false" -> false;
		      "true" -> true;
		      _ -> error
		  end,
	case BoolVal of
	    error -> {error, ?ERR_NOT_ACCEPTABLE};
	    _ -> set_xoption(Opts, add_opt(Opt, BoolVal, NewOpts), Type)
	end).

-define(SET_STRING_XOPT(Opt, Val),
	set_xoption(Opts, add_opt(Opt, Val, NewOpts), Type)).

-define(SET_INTEGER_XOPT(Opt, Val, Min, Max),
	case catch list_to_integer(Val) of
	    IVal when is_integer(IVal),
		      IVal >= Min,
		      IVal =< Max ->
		set_xoption(Opts, add_opt(Opt, IVal, NewOpts), Type);
	    _ ->
		{error, ?ERR_NOT_ACCEPTABLE}
	end).

-define(SET_ALIST_XOPT(Opt, Val, Vals),
	case lists:member(Val, [atom_to_list(V) || V <- Vals]) of
	    true ->
		set_xoption(Opts, add_opt(Opt, list_to_atom(Val), NewOpts), Type);
	    false ->
		{error, ?ERR_NOT_ACCEPTABLE}
	end).


set_xoption(Opts, [{defaults, Type} = Defaults | NewOpts]) ->
    OtherOpts = set_xoption(Opts, NewOpts, Type),
    if is_list(OtherOpts) ->
	    %% Make sure that "defaults" remains at head of option list.
	    [Defaults | set_xoption(Opts, NewOpts, Type)];
       true ->
	    %% If it's not a list, it's an {error, ...} tuple.  Leave
	    %% it as it is.
	    OtherOpts
    end;
set_xoption(Opts, NewOpts) ->
    set_xoption(Opts, NewOpts, pubsub_node).

set_xoption([], NewOpts, _Type) ->
    NewOpts;
set_xoption([{"FORM_TYPE", _} | Opts], NewOpts, Type) ->
    set_xoption(Opts, NewOpts, Type);
set_xoption([{"pubsub#deliver_payloads", [Val]} | Opts], NewOpts, Type) ->
    ?SET_BOOL_XOPT(deliver_payloads, Val);
set_xoption([{"pubsub#notify_config", [Val]} | Opts], NewOpts, Type) ->
    ?SET_BOOL_XOPT(notify_config, Val);
set_xoption([{"pubsub#notify_delete", [Val]} | Opts], NewOpts, Type) ->
    ?SET_BOOL_XOPT(notify_delete, Val);
set_xoption([{"pubsub#notify_retract", [Val]} | Opts], NewOpts, Type) ->
    ?SET_BOOL_XOPT(notify_retract, Val);
set_xoption([{"pubsub#persist_items", [Val]} | Opts], NewOpts, Type) ->
    ?SET_BOOL_XOPT(persist_items, Val);
set_xoption([{"pubsub#max_items", [Val]} | Opts], NewOpts, Type) ->
    ?SET_INTEGER_XOPT(max_items, Val, 0, ?MAXITEMS);
set_xoption([{"pubsub#subscribe", [Val]} | Opts], NewOpts, Type) ->
    ?SET_BOOL_XOPT(subscribe, Val);
set_xoption([{"pubsub#access_model", [Val]} | Opts], NewOpts, Type) ->
    AllowedModels = case Type of
			pubsub_node -> [open, authorize, whitelist];
			pep_node -> [open, presence, roster, whitelist]
		    end,
    ?SET_ALIST_XOPT(access_model, Val, AllowedModels);
set_xoption([{"pubsub#access_roster_groups", Values} | Opts], NewOpts, Type) ->
    set_xoption(Opts, add_opt(access_roster_groups, Values, NewOpts), Type);
set_xoption([{"pubsub#publish_model", [Val]} | Opts], NewOpts, Type) ->
    ?SET_ALIST_XOPT(publish_model, Val, [publishers, subscribers, open]);
set_xoption([{"pubsub#max_payload_size", [Val]} | Opts], NewOpts, Type) ->
    ?SET_INTEGER_XOPT(max_payload_size, Val, 0, ?MAX_PAYLOAD_SIZE);
set_xoption([{"pubsub#send_last_published_item", [Val]} | Opts], NewOpts, Type) ->
    ?SET_ALIST_XOPT(send_last_published_item, Val, [never, on_sub, on_sub_and_presence]);
set_xoption([{"pubsub#presence_based_delivery", [Val]} | Opts], NewOpts, Type) ->
    ?SET_BOOL_XOPT(presence_based_delivery, Val);
set_xoption([{"pubsub#current_approver", _} | Opts], NewOpts, Type) ->
    % TODO
    set_xoption(Opts, NewOpts, Type);
%set_xoption([{"title", [Val]} | Opts], NewOpts) ->
%    ?SET_STRING_XOPT(title, Val);
set_xoption([_ | _Opts], _NewOpts, _Type) ->
    {error, ?ERR_NOT_ACCEPTABLE}.


change_node_opts(Host, NewOpts, Node, Lang) ->
    Table = get_table(Host),
    F = fun() ->
		case mnesia:read({Table, {Host, Node}}) of
		    [N] ->
			Info = get_node_info(N),
			NewInfo = Info#nodeinfo{options = maybe_add_defaults(NewOpts, Table)},
			mnesia:write(set_node_info(N, NewInfo)),
			{result, []};
		    [] ->
			{error, ?ERR_ITEM_NOT_FOUND}
		end
	end,
    case mnesia:transaction(F) of
	{atomic, {error, _} = Error} ->
	    Error;
	{atomic, {result, Res}} ->
	    broadcast_config_notification(Host, Node, Lang),
	    {result, Res};
	_ ->
	    {error, ?ERR_INTERNAL_SERVER_ERROR}
    end.

maybe_add_defaults(NewOpts, Table) ->
    %% When we change node configuration, we add an explicit default
    %% marker, pubsub_node or pep_node.
    case NewOpts of
	[{defaults, _} | _] ->
	    NewOpts;
	_ ->
	    [{defaults, Table} | NewOpts]
    end.


get_present_resources({ToUser, ToServer, _}, {FromUser, FromServer, _}) ->
    get_present_resources(ToUser, ToServer, FromUser, FromServer).

get_present_resources(_ToUser, ToServer, FromUser, FromServer) ->
    %% Return a list of resources of FromUser@FromServer that have
    %% sent presence to ToUser@ToServer.  At least, that's the theory.
    %% In practice, we don't care whom the user sent presence to.
    %% Having the server in the key makes sure that each virtual host
    %% does what it should, though.
    Key = {ToServer, FromUser, FromServer},
    lists:map(fun(#pubsub_presence{resource = Res}) -> Res end,
	      case catch mnesia:dirty_read(pubsub_presence, Key) of
		  Result when is_list(Result) ->
		      Result;
		  _ ->
		      []
	      end).




update_table(Host) ->
    Fields = record_info(fields, pubsub_node),
    case mnesia:table_info(pubsub_node, attributes) of
	Fields ->
	    ok;
	[node, parent, info] ->
	    ?INFO_MSG("Converting pubsub_node table from "
		      "{node, parent, info} format", []),
	    {atomic, ok} = mnesia:create_table(
			     mod_pubsub_tmp_table,
			     [{disc_only_copies, [node()]},
			      {type, bag},
			      {local_content, true},
			      {record_name, pubsub_node},
			      {attributes, record_info(fields, pubsub_node)}]),
	    mnesia:del_table_index(pubsub_node, parent),
	    mnesia:transform_table(pubsub_node, ignore, Fields),
	    F1 = fun() ->
			 mnesia:write_lock_table(mod_pubsub_tmp_table),
			 mnesia:foldl(
			   fun(#pubsub_node{host_node = N,
					    host_parent = P} = R, _) ->
				   mnesia:dirty_write(
				     mod_pubsub_tmp_table,
				     R#pubsub_node{host_node = {Host, N},
						   host_parent = {Host, P}})
			   end, ok, pubsub_node)
		 end,
	    mnesia:transaction(F1),
	    mnesia:clear_table(pubsub_node),
	    F2 = fun() ->
			 mnesia:write_lock_table(pubsub_node),
			 mnesia:foldl(
			   fun(R, _) ->
				   mnesia:dirty_write(R)
			   end, ok, mod_pubsub_tmp_table)
		 end,
	    mnesia:transaction(F2),
	    mnesia:delete_table(mod_pubsub_tmp_table);
	_ ->
	    ?INFO_MSG("Recreating pubsub_node table", []),
	    mnesia:transform_table(pubsub_node, ignore, Fields)
    end.




