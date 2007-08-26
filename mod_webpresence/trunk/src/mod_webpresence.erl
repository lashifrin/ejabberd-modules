%%%----------------------------------------------------------------------
%%% File    : mod_presence.erl
%%% Author  : Igor Goryachev <igor@goryachev.org>
%%% Purpose : Module for showing presences via web
%%% Created : 30 Apr 2006 by Igor Goryachev <igor@goryachev.org>
%%% Id      : $Id$
%%%----------------------------------------------------------------------

-module(mod_presence).
-author('igor@goryachev.org').
-vsn('$Revision$ ').

-behaviour(gen_server).
-behaviour(gen_mod).

%% API
-export([start_link/2,
         start/2,
         stop/1,
         web_menu_host/2, web_page_host/3,
         process/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-include("ejabberd.hrl").
-include("jlib.hrl").
-include("ejabberd_web_admin.hrl").
-include("ejabberd_http.hrl").

-record(presence_registered, {us, id, xml, icon}).
-record(state, {host, server_host, access}).
-record(presence, {resource, show, priority, status}).

%% Copied from ejabberd_sm.erl
-record(session, {sid, usr, us, priority, info}).

-define(PROCNAME, ejabberd_mod_presence).

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
    mnesia:add_table_index(presence_registered, id),
    update_table(),
    MyHost = gen_mod:get_opt_host(Host, Opts, "presence.@HOST@"),
    Access = gen_mod:get_opt(access, Opts, local),
    ejabberd_router:register_route(MyHost),
    ejabberd_hooks:add(webadmin_menu_host, Host, ?MODULE, web_menu_host, 50),
    ejabberd_hooks:add(webadmin_page_host, Host, ?MODULE, web_page_host, 50),
    {ok, #state{host = MyHost,
		server_host = Host,
		access = Access}}.

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
terminate(_Reason, #state{host = Host}) ->
    ejabberd_router:unregister_route(Host),
    ejabberd_hooks:remove(webadmin_menu_host, Host, ?MODULE, web_menu_host, 50),
    ejabberd_hooks:remove(webadmin_page_host, Host, ?MODULE, web_page_host, 50),
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
    case acl:match_rule(ServerHost, Access, From) of
	allow ->
	    do_route1(Host, ServerHost, From, To, Packet);
	_ ->
	    {xmlelement, _Name, Attrs, _Els} = Packet,
	    Lang = xml:get_attr_s("xml:lang", Attrs),
	    ErrText = "Access denied by service policy",
	    Err = jlib:make_error_reply(Packet,
					?ERRT_FORBIDDEN(Lang, ErrText)),
	    ejabberd_router:route(To, From, Err)
    end.

%% TODO: Remove the nested case
do_route1(Host, _ServerHost, From, To, Packet) ->
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
                    xmlns = ?NS_DISCO_ITEMS} = _IQ ->
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
                    case process_iq_register_set(From, SubEl, Lang) of
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

%% @spec id_out(id()) -> "true" | "false"
%% @type id() = string() | false
id_out(false) -> "false";
id_out(Id) when is_list(Id) -> "true".

%% @spec id_in(Id_bool, Hash) -> Hash | false
%% ID_bool = true | false
%% Hash = string()
id_in(false, _) -> false;
id_in(true, Hash) -> Hash.

iq_get_register_info(Host, From, Lang) ->
    {LUser, LServer, _} = jlib:jid_tolower(From),
    LUS = {LUser, LServer},
    {_Id, XML, Icon, Registered} =
	case catch mnesia:dirty_read(presence_registered, LUS) of
	    {'EXIT', _Reason} ->
		{false, false, "disabled", []};
	    [] ->
		{false, false, "disabled", []};
	    [#presence_registered{id = ID, xml = X, icon = I}] ->
		{ID, X, I, [{xmlelement, "registered", [], []}]}
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
	   ?XFIELD("boolean", "Raw XML", "xml", atom_to_list(XML))]}].

iq_set_register_info(From, Id, XML, Icon, _Lang) ->
    {LUser, LServer, _} = jlib:jid_tolower(From),
    LUS = {LUser, LServer},
    F = fun() ->
		mnesia:write(
		  #presence_registered{us = LUS,
				       id = Id,
				       xml = XML,
				       icon = Icon})
	end,
    case mnesia:transaction(F) of
	{atomic, ok} ->
	    {result, []};
	_ ->
	    {error, ?ERR_INTERNAL_SERVER_ERROR}
    end.

%% TODO: Remove the nested cases
process_iq_register_set(From, SubEl, Lang) ->
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
					{value, {_, [XMLs]}} ->
                                            case lists:keysearch("icon", 1, XData) of
                                                false ->
                                                    ErrText = "You must fill in field \"Icon\" in the form",
                                                    {error, ?ERRT_NOT_ACCEPTABLE(Lang, ErrText)};
                                                {value, {_, [Icon]}} ->
						    Id = "false",
						    Hash = "aaaa",
						    iq_set_register_info(From, id_in(list_to_atom(Id), Hash), list_to_atom(XMLs), Icon, Lang)
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
	    iq_set_register_info(From, false, false, "disabled", Lang)
    end.

iq_get_vcard(Lang) ->
    [{xmlelement, "FN", [],
      [{xmlcdata, "ejabberd/mod_presence"}]},
     {xmlelement, "URL", [],
      [{xmlcdata,
	"http://ejabberd.jabber.ru/mod_presence"}]},
     {xmlelement, "DESC", [],
      [{xmlcdata, translate:translate(Lang, "ejabberd web presence module\n"
                                      "Copyright (c) 2006-2007 Igor Goryachev")}]}].

get_info(LUser, LServer) ->
    LUS = {LUser, LServer},
    case catch mnesia:dirty_read(presence_registered, LUS) of
        {'EXIT', _Reason} ->
            {false, "disabled"};
        [] ->
            {false, "disabled"};
        [#presence_registered{xml = XML, icon = Icon}] ->
            {XML, Icon}
    end.

get_status_weight(Show) ->
    case Show of
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
              {_User, _Resource, Show, Status} =
                  rpc:call(node(Pid), ejabberd_c2s, get_presence, [Pid]),
              Priority = Session#session.priority,
              #presence{resource = Resource,
                        show = Show,
                        priority = Priority,
                        status = Status}
      end,
      Resources);
get_presences({sorted, LUser, LServer}) ->
    lists:sort(
      fun(A, B) ->
              if
                  A#presence.priority == B#presence.priority ->
                      WA = get_status_weight(A#presence.show),
                      WB = get_status_weight(B#presence.show),
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
                 {"show", Presence#presence.show},
                 {"priority", integer_to_list(Presence#presence.priority)}],
                [{xmlcdata, Presence#presence.status}]}
       end,
       get_presences({sorted, LUser, LServer}))};
get_presences({show, LUser, LServer}) ->
    case get_presences({sorted, LUser, LServer}) of
        [Highest | _Rest] ->
            Highest#presence.show;
        _ ->
            "unavailable"
    end.

-define(XML_HEADER, "<?xml version='1.0' encoding='utf-8'?>").

get_pixmaps_directory() ->
    [{directory, Path} | _] = ets:lookup(pixmaps_dirs, directory),
    Path.

available_themes(list) ->
    case file:list_dir(get_pixmaps_directory()) of
        {ok, List} ->
            L2 = lists:sort(List),
	    %% Remove from the list of themes the directories that start with a dot
	    [T || T <- L2, hd(T) =/= 46];
        {error, _} ->
            []
    end;
available_themes(xdata) ->
    lists:map(
      fun(Theme) ->
              {xmlelement, "option", [{"label", Theme}],
               [{xmlelement, "value", [], [{xmlcdata, Theme}]}]}
      end, available_themes(list)).

show_presence({xml, LUser, LServer}) ->
    {true, _} = get_info(LUser, LServer),
    Presence_xml = xml:element_to_string(get_presences({xml, LUser, LServer})),
    {200, [{"Content-Type", "text/xml; charset=utf-8"}], ?XML_HEADER ++ Presence_xml};

show_presence({image, LUser, LServer}) ->
    {_, Icon} = get_info(LUser, LServer),
    "disabled" =/= Icon,
    show_presence({image_no_check, LUser, LServer, Icon});

show_presence({image, LUser, LServer, Theme}) ->
    {_, Icon} = get_info(LUser, LServer),
    "disabled" =/= Icon,
    show_presence({image_no_check, LUser, LServer, Theme});

show_presence({image_example, Theme, Show}) ->
    Dir = get_pixmaps_directory(),
    Image = Show ++ ".{gif,png,jpg}",
    [First | _Rest] = filelib:wildcard(filename:join([Dir, Theme, Image])),
    Mime = string:substr(First, string:len(First) - 2, 3),
    {ok, Content} = file:read_file(First),
    {200, [{"Content-Type", "image/" ++ Mime}], binary_to_list(Content)};

show_presence({image_no_check, LUser, LServer, Theme}) ->
    Dir = get_pixmaps_directory(),
    Image = get_presences({show, LUser, LServer}) ++ ".{gif,png,jpg}",
    [First | _Rest] = filelib:wildcard(filename:join([Dir, Theme, Image])),
    Mime = string:substr(First, string:len(First) - 2, 3),
    {ok, Content} = file:read_file(First),
    {200, [{"Content-Type", "image/" ++ Mime}], binary_to_list(Content)}.

make_xhtml(Els) -> make_xhtml([], Els).
make_xhtml(Title, Els) ->
    {xmlelement, "html", [{"xmlns", "http://www.w3.org/1999/xhtml"},
			  {"xml:lang", "en"},
			  {"lang", "en"}],
     [{xmlelement, "head", [],
       [{xmlelement, "meta", [{"http-equiv", "Content-Type"},
			      {"content", "text/html; charset=utf-8"}], []}]
       ++ Title},
      {xmlelement, "body", [], Els}
     ]}.

process(LocalPath, _Request) ->
    case catch process2(LocalPath, _Request) of
	{'EXIT', _Reason} ->
	    {404, [], make_xhtml([?XC("h1", "Not found")])};
	Res ->
	    Res
    end.


themes_to_xhtml(Themes) ->
    ShowL = ["chat", "available", "away", "xa", "dnd"],
    THeadL = [""] ++ ShowL,
    [?XAE("table", [], 
	  [?XE("tr", [?XC("th", T) || T <- THeadL])] ++
	  [?XE("tr", [?XC("td", Theme) |
		      [?XE("td", [?XA("img", [{"src", "image/"++Theme++"/"++T}])]) || T <- ShowL]
		     ]
	      ) || Theme <- Themes]
	 )
    ].

process2(["themes"], _Request) ->
    Title = [?XC("title", "Icon Themes")],
    Themes = available_themes(list),
    Icon_themes = themes_to_xhtml(Themes),
    Body = [?XC("h1", "Icon Themes")] ++ Icon_themes,
    make_xhtml(Title, Body);

process2([], _Request) ->
    Title = [?XC("title", "Web Presence")],
    Link_themes = [?AC("themes", "Icon Themes")],
    Body = [?XC("h1", "Web Presence")] ++ Link_themes,
    make_xhtml(Title, Body);

process2(["image", Theme, Show], _Request) ->
    Args = {image_example, Theme, Show},
    show_presence(Args);

process2([User, Server | Tail], _Request) ->
    LServer = jlib:nameprep(Server),
    true = lists:member(LServer, ?MYHOSTS),
    LUser = jlib:nodeprep(User),
    Args = case Tail of
	       ["xml"] -> 
		   {xml, LUser, LServer};
	       ["image"] -> 
		   {image, LUser, LServer};
	       ["image", Theme] -> 
		   {image, LUser, LServer, Theme}
	   end,
    show_presence(Args).


%% ---------------------
%% Web Admin
%% ---------------------

web_menu_host(Acc, _Host) ->
    [{"webpresence", "Web Presence"} | Acc].

web_page_host(_, _Host, 
	      #request{path = ["webpresence"],
		       lang = Lang} = _Request) ->
    Res = [?XC("h1", "Web Presence"),
	   ?ACT("users", "Registered Users")],
    {stop, Res};

web_page_host(_, Host, 
	      #request{path = ["webpresence", "users"],
		       lang = Lang} = _Request) ->
    Users = get_users(Host),
    Table = make_users_table(Users, Lang),
    Res = [?XC("h1", "Web Presence"),
	   ?XC("h2", "Registered Users")] ++ Table,
    {stop, Res};

web_page_host(Acc, _, _) -> Acc. 

get_users(Host) ->
    Select = [{{presence_registered, {'$1', Host}, '$2', '$3', '$4'}, [], ['$$']}],
    mnesia:dirty_select(presence_registered, Select).

make_users_table(Records, Lang) ->
    TList = lists:map(
	      fun([User, Id, XML, Icon]) ->
		      ?XE("tr",
			  [?XC("td", User),
			   ?XC("td", id_out(Id)),
			   ?XC("td", atom_to_list(XML)),
			   ?XC("td", Icon)])
	      end, Records),
    [?XE("table",
	 [?XE("thead",
	      [?XE("tr",
		   [?XCT("td", "User"),
		    ?XCT("td", "Id"),
		    ?XCT("td", "XML"),
		    ?XCT("td", "Icon")
		   ])]),
	  ?XE("tbody", TList)])].


%%%--------------------------------
%%% Update table schema and content from older versions
%%%--------------------------------

update_table() ->
    Fields = record_info(fields, presence_registered),
    case mnesia:table_info(presence_registered, attributes) of
	Fields ->
	    ok;
	[us_host, xml, icon] ->
	    convert_table_004(Fields)
    end.

convert_table_004(Fields) ->
    mnesia:del_table_index(presence_registered, xml),
    mnesia:del_table_index(presence_registered, icon),

    FixRecords = fun(Old) ->
			 {presence_registered, {US, Host}, XML, Icon} = Old,
			 #presence_registered{us = {US, Host},
					      xml = list_to_atom(XML),
					      icon = Icon}
		 end,
    {atomic, ok} = mnesia:transform_table(presence_registered, FixRecords, Fields, presence_registered),

    F = fun() ->
		FixKey = fun(Old, Acc) ->
				 {US, _Host} = Old#presence_registered.us,
				 New = Old#presence_registered{us = US},
				 mnesia:delete_object(Old),
				 mnesia:write(New),
				 Acc
			 end,
		mnesia:foldl(FixKey, none, presence_registered)
	end,
    mnesia:transaction(F).

