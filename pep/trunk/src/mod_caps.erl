%%%----------------------------------------------------------------------
%%% File    : mod_caps.erl
%%% Author  : Magnus Henoch <henoch@dtek.chalmers.se>
%%% Purpose : Request and cache Entity Capabilities (XEP-0115)
%%% Created : 7 Oct 2006 by Magnus Henoch <henoch@dtek.chalmers.se>
%%% Id      : $Id: ejabberd_c2s.erl 657 2006-10-01 01:53:37Z alexey $
%%%----------------------------------------------------------------------

-module(mod_caps).
-author('henoch@dtek.chalmers.se').

-behaviour(gen_server).
-behaviour(gen_mod).

-export([read_caps/1,
	 note_caps/3,
	 get_features/2,
	 handle_disco_response/3]).

%% gen_mod callbacks
-export([start/2, start_link/2,
	 stop/1]).

%% gen_server callbacks
-export([init/1,
	 handle_info/2,
	 handle_call/3,
	 handle_cast/2,
	 terminate/2,
	 code_change/3
	]).

-include("ejabberd.hrl").
-include("jlib.hrl").
-include("jlib-pep.hrl").

-define(PROCNAME, ejabberd_mod_caps).
-define(DICT, dict).

-record(caps, {node, version, exts}).
-record(caps_features, {node_pair, features}).
-record(state, {host,
		requests = ?DICT:new()}).

%% read_caps takes a list of XML elements (the child elements of a
%% <presence/> stanza) and returns an opaque value representing the
%% Entity Capabilities contained therein, or the atom nothing if no
%% capabilities are advertised.
read_caps([{xmlelement, "c", Attrs, _Els} | Tail]) ->
    case xml:get_attr_s("xmlns", Attrs) of
	?NS_CAPS ->
	    Node = xml:get_attr_s("node", Attrs),
	    Version = xml:get_attr_s("ver", Attrs),
	    Exts = string:tokens(xml:get_attr_s("ext", Attrs), " "),
	    #caps{node = Node, version = Version, exts = Exts};
	_ ->
	    read_caps(Tail)
    end;
read_caps([_ | Tail]) ->
    read_caps(Tail);
read_caps([]) ->
    nothing.

%% note_caps should be called to make the module request disco
%% information.  Host is the host that asks, From is the full JID that
%% sent the caps packet, and Caps is what read_caps returned.
note_caps(Host, From, Caps) ->
    case Caps of
	nothing -> ok;
	_ ->
	    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
	    gen_server:cast(Proc, {note_caps, From, Caps})
    end.

%% get_features returns a list of features implied by the given caps
%% record (as extracted by read_caps).  It may block, and may signal a
%% timeout error.
get_features(Host, Caps) ->
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    gen_server:call(Proc, {get_features, Caps}).

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

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([Host, _Opts]) ->
    mnesia:create_table(caps_features,
			[{ram_copies, [node()]},
			 {attributes, record_info(fields, caps_features)}]),
    {ok, #state{host = Host}}.


%% XXX: implement get_features here
handle_call({get_features, _}, _From, State) ->
    %% Fake a timeout
    {noreply, State};

handle_call(stop, _From, State) ->
    {stop, normal, ok, State}.

handle_cast({note_caps, From, 
	     #caps{node = Node, version = Version, exts = Exts}}, 
	    #state{host = Host, requests = Requests} = State) ->
    %% XXX: this leads to race conditions where ejabberd will send
    %% lots of caps disco requests.
    SubNodes = [Version | Exts],
    %% Now, find which of these are not already in the database.
    Fun = fun() ->
		  lists:foldl(fun(SubNode, Acc) ->
				      case mnesia:read({caps_features, {Node, SubNode}}) of
					  [] ->
					      [SubNode | Acc];
					  _ ->
					      Acc
				      end
			      end, [], SubNodes)
	  end,
    case mnesia:transaction(Fun) of
	{atomic, Missing} ->
	    NewRequests =
		lists:foldl(
		  fun(SubNode, Dict) ->
			  ID = randoms:get_string(),
			  Stanza =
			      {xmlelement, "iq",
			       [{"type", "get"},
				{"id", ID}],
			       [{xmlelement, "query",
				 [{"xmlns", ?NS_DISCO_INFO},
				  {"node", Node ++ "#" ++ SubNode}],
				 []}]},
			  ejabberd_local:register_iq_response_handler
			    (Host, ID, ?MODULE, handle_disco_response),
			  ejabberd_router:route(jlib:make_jid("", Host, ""), From, Stanza),
			  ?DICT:store(ID, {Node, SubNode}, Dict)
		  end, Requests, Missing),
	    {noreply, State#state{requests = NewRequests}};
	Error ->
	    ?ERROR_MSG("Transaction failed: ~p", [Error]),
	    {noreply, State}
    end;
handle_cast({disco_response, From, _To, 
	     #iq{type = Type, id = ID,
		 sub_el = SubEls}},
	    #state{requests = Requests} = State) ->
    case {Type, SubEls} of
	{result, [{xmlelement, "query", Attrs, Els}]} ->
	    %% Did we get the correct node?
	    ResultNode = xml:get_attr_s("node", Attrs),
	    case catch ?DICT:fetch(ID, Requests) of
		{Node, SubNode} ->
		    case (Node ++ "#" ++ SubNode) of
			ResultNode ->
			    Features =
				lists:flatmap(fun({xmlelement, "feature", FAttrs, _}) ->
						      [xml:get_attr_s("var", FAttrs)];
						 (_) ->
						      []
					      end, Els),
			    mnesia:transaction(
			      fun() ->
				      mnesia:write(#caps_features{node_pair = {Node, SubNode},
								  features = Features})
			      end);
			_ ->
			    ?ERROR_MSG("We asked for ~s#~s, but got ~s", [Node, SubNode, ResultNode])
		    end;
		_ ->
		    ?ERROR_MSG("ID '~s' matches no query", [ID])
	    end;
	{result, _} ->
	    ?ERROR_MSG("Invalid IQ contents from ~s: ~p", [jlib:jid_to_string(From), SubEls]);
	_ ->
	    %% Can't do anything about errors
	    ok
    end,
    NewRequests = ?DICT:erase(ID, Requests),
    {noreply, State#state{requests = NewRequests}}.

handle_disco_response(From, To, IQ) ->
    #jid{lserver = Host} = To,
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    gen_server:cast(Proc, {disco_response, From, To, IQ}).

handle_info(Info, State) ->
    {noreply, State}.

terminate(Reason, State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
