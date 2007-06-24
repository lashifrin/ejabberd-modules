%%%----------------------------------------------------------------------
%%% File    : mod_presence.erl
%%% Author  : Igor Goryachev <igor@goryachev.org>
%%% Purpose : Module for showing presences via web
%%% Created : 30 Apr 2006 by Igor Goryachev <igor@goryachev.org>
%%% Id      : $Id$
%%%----------------------------------------------------------------------

-module(mod_presence).
-author('igor@goryachev.org').
-vsn('$Revision$').

-behaviour(gen_server).
-behaviour(gen_mod).

%% API
-export([start_link/2,
         start/2,
         stop/1,
         get_info/2,
         process/2,
         show_presence/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-include("ejabberd.hrl").
-include("jlib.hrl").

-record(presence_registered, {us_host, xml, icon}).
-record(state, {host, server_host, access}).
-record(presence, {resource, status, priority, text}).

%% Copied from ejabberd_sm.erl
-record(session, {sid, usr, us, priority, info}).

-define(PROCNAME, ejabberd_mod_presence).
-define(SERVICE_NAME(Host), "presence." ++ Host).

-define(PIXMAPS_DIR, "pixmaps").


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
	 temporary,
	 1000,
	 worker,
	 [?MODULE]},
    Default_dir = case code:priv_dir(ejabberd) of
		{error, _} -> ?PIXMAPS_DIR;
		Path -> filename:join([Path, ?PIXMAPS_DIR])
    end,
    Dir = gen_mod:get_opt(pixmaps_path, Opts, Default_dir),
    catch ets:new(pixmaps_dirs, [named_table, public]),
    ets:insert(pixmaps_dirs, {directory, Dir}),
    supervisor:start_child(ejabberd_sup, ChildSpec).

stop(Host) ->
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    gen_server:call(Proc, stop),
    supervisor:stop_child(ejabberd_sup, Proc).

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
init([Host, Opts]) ->
    mnesia:create_table(presence_registered,
			[{disc_copies, [node()]},
			 {attributes, record_info(fields, presence_registered)}]),
    MyHost = gen_mod:get_opt(host, Opts, ?SERVICE_NAME(Host)),
    mnesia:add_table_index(presence_registered, xml),
    mnesia:add_table_index(presence_registered, icon),
    Access = gen_mod:get_opt(access, Opts, all),
    AccessCreate = gen_mod:get_opt(access_create, Opts, all),
    AccessAdmin = gen_mod:get_opt(access_admin, Opts, none),
    ejabberd_router:register_route(MyHost),
    {ok, #state{host = MyHost,
		server_host = Host,
		access = {Access, AccessCreate, AccessAdmin}}}.

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
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% Function: handle_info(Info, State) -> {noreply, State} |
%%                                       {noreply, State, Timeout} |
%%                                       {stop, Reason, State}
%% Description: Handling all non call/cast messages
%%--------------------------------------------------------------------
handle_info({route, From, To, Packet},
	    #state{host = Host,
		   server_host = ServerHost,
		   access = Access} = State) ->
    case catch do_route(Host, ServerHost, Access, From, To, Packet) of
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
    ejabberd_router:unregister_route(State#state.host),
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
    {AccessRoute, _AccessCreate, _AccessAdmin} = Access,
    case acl:match_rule(ServerHost, AccessRoute, From) of
	allow ->
	    do_route1(Host, ServerHost, Access, From, To, Packet);
	_ ->
	    {xmlelement, _Name, Attrs, _Els} = Packet,
	    Lang = xml:get_attr_s("xml:lang", Attrs),
	    ErrText = "Access denied by service policy",
	    Err = jlib:make_error_reply(Packet,
					?ERRT_FORBIDDEN(Lang, ErrText)),
	    ejabberd_router:route(To, From, Err)
    end.

do_route1(Host, ServerHost, Access, From, To, Packet) ->
    {_AccessRoute, AccessCreate, AccessAdmin} = Access,
    {xmlelement, Name, Attrs, _Els} = Packet,
    case Name of
        "iq" ->
            case jlib:iq_query_info(Packet) of
                #iq{type = get, xmlns = ?NS_DISCO_INFO = XMLNS,
                    sub_el = _SubEl} = IQ ->
                    Res = IQ#iq{type = result,
                                sub_el = [{xmlelement, "query",
                                           [{"xmlns", XMLNS}],
                                           iq_disco_info()}]},
                    ejabberd_router:route(To,
                                          From,
                                          jlib:iq_to_xml(Res));
                #iq{type = get,
                    xmlns = ?NS_DISCO_ITEMS} = IQ ->
                    ok;
                #iq{type = get,
                    xmlns = ?NS_REGISTER = XMLNS,
                    lang = Lang,
                    sub_el = _SubEl} = IQ ->
                    Res = IQ#iq{type = result,
                                sub_el =
                                [{xmlelement, "query",
                                  [{"xmlns", XMLNS}],
                                  iq_get_register_info(
                                    Host, From, Lang)}]},
                    ejabberd_router:route(To,
                                          From,
                                          jlib:iq_to_xml(Res));
                #iq{type = set,
                    xmlns = ?NS_REGISTER = XMLNS,
                    lang = Lang,
                    sub_el = SubEl} = IQ ->
                    case process_iq_register_set(Host, From, SubEl, Lang) of
                        {result, IQRes} ->
                            Res = IQ#iq{type = result,
                                        sub_el =
                                        [{xmlelement, "query",
                                          [{"xmlns", XMLNS}],
                                          IQRes}]},
                            ejabberd_router:route(
                              To, From, jlib:iq_to_xml(Res));
                        {error, Error} ->
                            Err = jlib:make_error_reply(
                                    Packet, Error),
                            ejabberd_router:route(
                              To, From, Err)
                    end;
                #iq{type = get,
                    xmlns = ?NS_VCARD = XMLNS,
                    lang = Lang,
                    sub_el = _SubEl} = IQ ->
                    Res = IQ#iq{type = result,
                                sub_el =
                                [{xmlelement, "vCard",
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

iq_disco_info() ->
    [{xmlelement, "identity",
      [{"category", "presence"},
       {"type", "text"},
       {"name", "Web Presence"}], []},
     {xmlelement, "feature", [{"var", ?NS_REGISTER}], []},
     {xmlelement, "feature", [{"var", ?NS_VCARD}], []}].

-define(XFIELD(Type, Label, Var, Val),
        {xmlelement, "field", [{"type", Type},
                               {"label", translate:translate(Lang, Label)},
                               {"var", Var}],
         [{xmlelement, "value", [], [{xmlcdata, Val}]}]}).

iq_get_register_info(Host, From, Lang) ->
    {LUser, LServer, _} = jlib:jid_tolower(From),
    LUS = {LUser, LServer},
    {XML, Icon, Registered} =
	case catch mnesia:dirty_read(presence_registered, {LUS, Host}) of
	    {'EXIT', _Reason} ->
		{"false", "disabled", []};
	    [] ->
		{"false", "disabled", []};
	    [#presence_registered{xml = X, icon = I}] ->
		{X, I, [{xmlelement, "registered", [], []}]}
	end,
    Registered ++
	[{xmlelement, "instructions", [],
	  [{xmlcdata,
	    translate:translate(
	      Lang, "You need an x:data capable client to register presence")}]},
	 {xmlelement, "x",
	  [{"xmlns", ?NS_XDATA}],
	  [{xmlelement, "title", [],
	    [{xmlcdata,
	      translate:translate(
		Lang, "Presence registration at ") ++ Host}]},
	   {xmlelement, "instructions", [],
	    [{xmlcdata,
	      translate:translate(
		Lang, "What presence features do you want to register?")}]},
           {xmlelement, "field", [{"type", "list-single"},
                                  {"label", "Icon theme"},
                                  {"var", "icon"}],
            [{xmlelement, "value", [], [{xmlcdata, Icon}]},
             {xmlelement, "option", [{"label", "disabled"}],
              [{xmlelement, "value", [], [{xmlcdata, "disabled"}]}]}             
            ] ++ available_themes(xdata)},
	   ?XFIELD("boolean", "Raw XML", "xml", XML)]}].

iq_set_register_info(Host, From, XML, Icon, _Lang) ->
    {LUser, LServer, _} = jlib:jid_tolower(From),
    LUS = {LUser, LServer},
    F = fun() ->
	mnesia:write(
	  #presence_registered{us_host = {LUS, Host},
		  xml = XML,
                  icon = Icon})
    end,
    case mnesia:transaction(F) of
	{atomic, ok} ->
	    {result, []};
	_ ->
	    {error, ?ERR_INTERNAL_SERVER_ERROR}
    end.

process_iq_register_set(Host, From, SubEl, Lang) ->
    {xmlelement, _Name, _Attrs, Els} = SubEl,
    case xml:get_subtag(SubEl, "remove") of
	false ->
	    case xml:remove_cdata(Els) of
		[{xmlelement, "x", _Attrs1, _Els1} = XEl] ->
		    case {xml:get_tag_attr_s("xmlns", XEl),
			  xml:get_tag_attr_s("type", XEl)} of
			{?NS_XDATA, "cancel"} ->
			    {result, []};
			{?NS_XDATA, "submit"} ->
			    XData = jlib:parse_xdata_submit(XEl),
			    case XData of
				invalid ->
				    {error, ?ERR_BAD_REQUEST};
				_ ->
				    case lists:keysearch("xml", 1, XData) of
					false ->
					    ErrText = "You must fill in field \"Xml\" in the form",
					    {error, ?ERRT_NOT_ACCEPTABLE(Lang, ErrText)};
					{value, {_, [XML]}} ->
                                            case lists:keysearch("icon", 1, XData) of
                                                false ->
                                                    ErrText = "You must fill in field \"Icon\" in the form",
                                                    {error, ?ERRT_NOT_ACCEPTABLE(Lang, ErrText)};
                                                {value, {_, [Icon]}} ->
                                                    iq_set_register_info(Host, From, XML, Icon, Lang)
                                            end
				    end
			    end;
			_ ->
			    {error, ?ERR_BAD_REQUEST}
		    end;
		_ ->
		    {error, ?ERR_BAD_REQUEST}
	    end;
	_ ->
	    iq_set_register_info(Host, From, "false", "disabled", Lang)
    end.

iq_get_vcard(Lang) ->
    [{xmlelement, "FN", [],
      [{xmlcdata, "ejabberd/mod_presence"}]},
     {xmlelement, "URL", [],
      [{xmlcdata,
	"http://ejabberd.jabberstudio.org/"}]},
     {xmlelement, "DESC", [],
      [{xmlcdata, translate:translate(Lang, "ejabberd presence module\n"
                                      "Copyright (c) 2006 Igor Goryachev")}]}].

get_info(LUser, LServer) ->
    LUS = {LUser, LServer},
    case catch mnesia:dirty_read(presence_registered, {LUS, ?SERVICE_NAME(LServer)}) of
        {'EXIT', _Reason} ->
            {false, disabled};
        [] ->
            {false, disabled};
        [#presence_registered{xml = X, icon = I}] ->
            X1 = case X of
                     "0" -> false;
                     "1" -> true;
                     _   -> list_to_atom(X)
                 end,
            {X1, list_to_atom(I)}
    end.

get_status_weight(Status) ->
    case Status of
        "chat"      -> 0;
        "available" -> 1;
        "away"      -> 2;
        "xa"        -> 3;
        "dnd"       -> 4;
        _           -> 9
    end.


get_presences({bare, LUser, LServer}) ->
    Resources = ejabberd_sm:get_user_resources(LUser, LServer),
    lists:map(
      fun(Resource) ->
              [Session] = mnesia:dirty_index_read(session,
                                                  {LUser, LServer, Resource},
                                                  #session.usr),
              Pid = element(2, Session#session.sid),
              {_User, _Resource, Status, Text} =
                  rpc:call(node(Pid), ejabberd_c2s, get_presence, [Pid]),
              Priority = Session#session.priority,
              #presence{resource = Resource,
                        status = Status,
                        priority = Priority,
                        text = Text}
      end,
      Resources);
get_presences({sorted, LUser, LServer}) ->
    lists:sort(
      fun(A, B) ->
              if
                  A#presence.priority == B#presence.priority ->
                      WA = get_status_weight(A#presence.status),
                      WB = get_status_weight(B#presence.status),
                      WA < WB;
                  true ->
                      A#presence.priority > B#presence.priority
              end
      end,
      get_presences({bare, LUser, LServer}));
get_presences({xml, LUser, LServer}) ->
    {xmlelement, "presence",
     [{"user", LUser}, {"server", LServer}],
     lists:map(
       fun(Presence) ->
               {xmlelement, "resource",
                [{"name", Presence#presence.resource},
                 {"status", Presence#presence.status},
                 {"priority", integer_to_list(Presence#presence.priority)}],
                [{xmlcdata, Presence#presence.text}]}
       end,
       get_presences({sorted, LUser, LServer}))};
get_presences({status, LUser, LServer}) ->
    case get_presences({sorted, LUser, LServer}) of
        [Highest | _Rest] ->
            Highest#presence.status;
        _ ->
            "unavailable"
    end;
get_presences(_) ->
    [].

-define(XML_HEADER, "<?xml version='1.0' encoding='utf-8'?>").

get_pixmaps_directory() ->
    [{directory, Path} | _] = ets:lookup(pixmaps_dirs, directory),
    Path.

available_themes(list) ->
    case file:list_dir(get_pixmaps_directory()) of
        {ok, List} ->
            List;
        {error, _} ->
            []
    end;
available_themes(xdata) ->
    lists:map(
      fun(Theme) ->
              {xmlelement, "option", [{"label", Theme}],
               [{xmlelement, "value", [], [{xmlcdata, Theme}]}]}
      end, available_themes(list));
available_themes(_) ->
    [].

-define(XE(Name, Els), {xmlelement, Name, [], Els}).
-define(C(Text), {xmlcdata, Text}).
-define(XC(Name, Text), ?XE(Name, [?C(Text)])).

show_presence({xml, LUser, LServer}) ->
    {XML, _Icon} = get_info(LUser, LServer),
    case XML of
        true ->
            {200, [{"Content-Type", "text/xml; charset=utf-8"}],
             ?XML_HEADER ++ xml:element_to_string(
                              get_presences({xml, LUser, LServer}))};
        _ ->
            {404, [], ejabberd_web:make_xhtml([?XC("h1", "Not found")])}
    end;
show_presence({image, LUser, LServer}) ->
    {_XML, Icon} = get_info(LUser, LServer),
    case Icon of
        disabled ->
            {404, [], ejabberd_web:make_xhtml([?XC("h1", "Not found")])};
        _ ->
            show_presence({image_no_check, LUser, LServer, atom_to_list(Icon)})
    end;
show_presence({image, LUser, LServer, Theme}) ->
    {_XML, Icon} = get_info(LUser, LServer),
    case Icon of
        disabled ->
            {404, [], ejabberd_web:make_xhtml([?XC("h1", "Not found")])};
        _ ->
            show_presence({image_no_check, LUser, LServer, Theme})
    end;
show_presence({image_no_check, LUser, LServer, Theme}) ->
    case lists:member(Theme, available_themes(list)) of
        true ->
            case filelib:wildcard(
                   filename:join([get_pixmaps_directory(), Theme,
                                  get_presences(
                                    {status, LUser, LServer}) ++ ".{gif,png,jpg}"])) of
                [First | _Rest] ->
                    CT = case string:substr(First, string:len(First) - 2, 3) of
                             "gif" -> "gif";
                             "png" -> "png";
                             "jpg" -> "jpeg"
                         end,
                    case file:read_file(First) of
                        {ok, Content} ->
                            {200, [{"Content-Type", "image/" ++ CT}],
                             binary_to_list(Content)};
                        _ ->
                            {404, [], ejabberd_web:make_xhtml([?XC("h1", "Not found")])}
                    end;
                _ ->
                    {404, [], ejabberd_web:make_xhtml([?XC("h1", "Not found")])}
            end;
        false ->
            {404, [], ejabberd_web:make_xhtml([?XC("h1", "Not found")])}
    end;
show_presence(_) ->
    {404, [], ejabberd_web:make_xhtml([?XC("h1", "Not found")])}.


make_xhtml(Els) ->
    {xmlelement, "html", [{"xmlns", "http://www.w3.org/1999/xhtml"},
			  {"xml:lang", "en"},
			  {"lang", "en"}],
     [{xmlelement, "head", [],
       [{xmlelement, "meta", [{"http-equiv", "Content-Type"},
			      {"content", "text/html; charset=utf-8"}], []}]},
      {xmlelement, "body", [], Els}
     ]}.

process(LocalPath, Request) ->
    case LocalPath of
        [User, Server | Tail] ->
            LServer = jlib:nameprep(Server),
            case lists:member(LServer, ?MYHOSTS) of
                true ->
                    LUser = jlib:nodeprep(User),
                    case Tail of
                        ["xml"] ->
                            mod_presence:show_presence({xml, LUser, LServer});
                        ["image"] ->
                            mod_presence:show_presence({image, LUser, LServer});
                        ["image", Theme] ->
                            mod_presence:show_presence({image, LUser, LServer, Theme});
                        _ ->
                            {404, [], make_xhtml([?XC("h1", "Not found")])}
                    end;
                false ->
                    {404, [], make_xhtml([?XC("h1", "Not found")])}
            end;
        _ ->
            {404, [], make_xhtml([?XC("h1", "Not found")])}
    end.
