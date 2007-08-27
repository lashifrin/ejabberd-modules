%%%----------------------------------------------------------------------
%%% File    : mod_webpresence.erl
%%% Author  : Igor Goryachev <igor@goryachev.org>
%%% Purpose : Allow user to show presence in the web
%%% Created : 30 Apr 2006 by Igor Goryachev <igor@goryachev.org>
%%% Id      : $Id$
%%%----------------------------------------------------------------------

-module(mod_webpresence).
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

-record(webpresence, {us, hashurl = false, jidurl = false, xml = false, avatar = false, icon = "disabled"}).
-record(state, {host, server_host, access}).
-record(presence, {resource, show, priority, status}).

%% Copied from ejabberd_sm.erl
-record(session, {sid, usr, us, priority, info}).

-define(PROCNAME, ejabberd_mod_webpresence).

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
    mnesia:create_table(webpresence,
			[{disc_copies, [node()]},
			 {attributes, record_info(fields, webpresence)}]),
    mnesia:add_table_index(webpresence, hashurl),
    update_table(),
    MyHost = gen_mod:get_opt_host(Host, Opts, "webpresence.@HOST@"),
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
	    do_route1(Host, From, To, Packet);
	_ ->
	    {xmlelement, _Name, Attrs, _Els} = Packet,
	    Lang = xml:get_attr_s("xml:lang", Attrs),
	    ErrText = "Access denied by service policy",
	    Err = jlib:make_error_reply(Packet, ?ERRT_FORBIDDEN(Lang, ErrText)),
	    ejabberd_router:route(To, From, Err)
    end.

do_route1(Host, From, To, Packet) ->
    {xmlelement, Name, Attrs, _Els} = Packet,
    case Name of
        "iq" -> do_route1_iq(Host, From, To, Packet, jlib:iq_query_info(Packet));
        _ -> case xml:get_attr_s("type", Attrs) of
		 "error" -> ok;
		 "result" -> ok;
		 _ -> Err = jlib:make_error_reply(Packet, ?ERR_ITEM_NOT_FOUND),
		      ejabberd_router:route(To, From, Err)
	     end
    end.

do_route1_iq(_, From, To, _,
	     #iq{type = get, xmlns = ?NS_DISCO_INFO} = IQ) ->
    SubEl2 = {xmlelement, "query", [{"xmlns", ?NS_DISCO_INFO}], iq_disco_info()},
    Res = IQ#iq{type = result, sub_el = [SubEl2]},
    ejabberd_router:route(To, From, jlib:iq_to_xml(Res));

do_route1_iq(_, _, _, _,
	     #iq{type = get, xmlns = ?NS_DISCO_ITEMS}) ->
    ok;

do_route1_iq(Host, From, To, _,
	     #iq{type = get, xmlns = ?NS_REGISTER, lang = Lang} = IQ) ->
    SubEl2 = {xmlelement, "query", [{"xmlns", ?NS_REGISTER}], iq_get_register_info(Host, From, Lang)},
    Res = IQ#iq{type = result, sub_el = [SubEl2]},
    ejabberd_router:route(To, From, jlib:iq_to_xml(Res));

do_route1_iq(Host, From, To, Packet,
	     #iq{type = set, xmlns = ?NS_REGISTER, lang = Lang, sub_el = SubEl} = IQ) ->
    case process_iq_register_set(From, SubEl, Host, Lang) of
	{result, IQRes} ->
	    SubEl2 = {xmlelement, "query", [{"xmlns", ?NS_REGISTER}], IQRes},
	    Res = IQ#iq{type = result, sub_el = [SubEl2]},
	    ejabberd_router:route(To, From, jlib:iq_to_xml(Res));
	{error, Error} ->
	    Err = jlib:make_error_reply(Packet, Error),
	    ejabberd_router:route(To, From, Err)
    end;

do_route1_iq(_Host, From, To, _,
	     #iq{type = get, xmlns = ?NS_VCARD = XMLNS, lang = Lang} = IQ) ->
    SubEl2 = {xmlelement, "vCard", [{"xmlns", XMLNS}], iq_get_vcard(Lang)},
    Res = IQ#iq{type = result, sub_el = [SubEl2]},
    ejabberd_router:route(To, From, jlib:iq_to_xml(Res));

do_route1_iq(_Host, From, To, Packet, #iq{}) ->
    Err = jlib:make_error_reply( Packet, ?ERR_FEATURE_NOT_IMPLEMENTED),
    ejabberd_router:route(To, From, Err);

do_route1_iq(_, _, _, _, _) ->
    ok.

iq_disco_info() ->
    [{xmlelement, "identity",
      [{"category", "presence"},
       {"type", "text"},
       {"name", "Web Presence"}], []},
     {xmlelement, "feature", [{"var", ?NS_REGISTER}], []},
     {xmlelement, "feature", [{"var", ?NS_VCARD}], []}].

-define(XFIELDS(Type, Label, Var, Vals),
        {xmlelement, "field", [{"type", Type},
                               {"label", translate:translate(Lang, Label)},
                               {"var", Var}],
         Vals}).

-define(XFIELD(Type, Label, Var, Val),
	?XFIELDS(Type, Label, Var, 
		 [{xmlelement, "value", [], [{xmlcdata, Val}]}])
       ).

%% @spec hashurl_out(id()) -> hash()
%% @type id() = string() | false
%% @type hash() = "true" | "false"
hashurl_out(false) -> "false";
hashurl_out(Id) when is_list(Id) -> "true".

to_bool("false") -> false;
to_bool("true") -> true;
to_bool("0") -> false;
to_bool("1") -> true.

get_pr(LUS) ->
    case catch mnesia:dirty_read(webpresence, LUS) of
	[#webpresence{jidurl = J, hashurl = H, xml = X, avatar = A, icon = I}] ->
	    {J, H, X, A, I, true};
	_ ->
	    {true, false, false, false, "disabled", false}
    end.

get_pr_hash(LUS) ->
    {_, H, _, _, _, _} = get_pr(LUS),
    H.

iq_get_register_info(Host, From, Lang) ->
    {LUser, LServer, _} = jlib:jid_tolower(From),
    LUS = {LUser, LServer},
    {JidUrl, HashUrl, XML, Avatar, Icon, Registered} = get_pr(LUS),
    RegisteredXML = case Registered of 
			true -> [{xmlelement, "registered", [], []}];
			false -> []
		    end,
    RegisteredXML ++
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
	   ?XFIELD("boolean", "Allow JID URL", "jidurl", atom_to_list(JidUrl)),
	   ?XFIELD("boolean", "Allow Hash URL", "hashurl", hashurl_out(HashUrl)),
	   ?XFIELDS("list-single", "Icon theme", "icon", 
		    [{xmlelement, "value", [], [{xmlcdata, Icon}]},
		     {xmlelement, "option", [{"label", "disabled"}],
		      [{xmlelement, "value", [], [{xmlcdata, "disabled"}]}]}             
		    ] ++ available_themes(xdata)
		   ),
	   ?XFIELD("boolean", "Avatar", "avatar", atom_to_list(Avatar)),
	   ?XFIELD("boolean", "Raw XML", "xml", atom_to_list(XML))]}].

%% TODO: Check if remote users are allowed to reach here: they should not be allowed
iq_set_register_info(From, Host, JidUrl, HashUrl, XML, Avatar, Icon, _Lang) ->
    {LUser, LServer, _} = jlib:jid_tolower(From),
    LUS = {LUser, LServer},
    HashUrl2 = get_hashurl_final_value(HashUrl, LUS),
    F = fun() ->
		mnesia:write(
		  #webpresence{us = LUS,
			       jidurl = JidUrl,
			       hashurl = HashUrl2,
			       xml = XML,
			       avatar = Avatar,
			       icon = Icon})
	end,
    case mnesia:transaction(F) of
	{atomic, ok} ->
	    send_hash_message(HashUrl2, From, Host),
	    {result, []};
	_ ->
	    {error, ?ERR_INTERNAL_SERVER_ERROR}
    end.

get_hashurl_final_value(false, _) -> false;
get_hashurl_final_value(true, {U, S} = LUS) ->
    case get_pr_hash(LUS) of
	false ->
	    integer_to_list(erlang:phash2(U) * erlang:phash2(S) 
			    * calendar:datetime_to_gregorian_seconds(
				calendar:local_time())) 
		++ randoms:get_string();
	H when is_list(H) ->
	    H
    end.

send_hash_message(false, _, _) -> ok;
send_hash_message(Hash, To, Host) ->
    ejabberd_router:route(
      jlib:make_jid("", Host, ""),
      To,
      {xmlelement, "message", [{"type", "headline"}],
       [{xmlelement, "subject", [], [{xmlcdata, "Hash for your Web Presence"}]},
	{xmlelement, "body", [], [{xmlcdata, "You enabled Hash URL in Web Presence.\r\n"
				   "Your Hash value is: "++Hash++"\r\n"
				   "The URL that you can use looks similar to: "
				   "http://example.org:5280/presence/hash/"++Hash++"/image/"}]}]}).

get_attr(Attr, XData, Default) ->
    case lists:keysearch(Attr, 1, XData) of
	{value, {_, [Value]}} -> Value;
	false -> Default
    end.

process_iq_register_set(From, SubEl, Host, Lang) ->
    {xmlelement, _Name, _Attrs, Els} = SubEl,
    case xml:get_subtag(SubEl, "remove") of
	false -> case catch process_iq_register_set2(From, Els, Host, Lang) of
		     {'EXIT', _} -> {error, ?ERR_BAD_REQUEST};
		     R -> R
		 end;
	_ -> iq_set_register_info(From, Host, true, false, false, false, "disabled", Lang)
    end.

process_iq_register_set2(From, Els, Host, Lang) ->
    [{xmlelement, "x", _Attrs1, _Els1} = XEl] = xml:remove_cdata(Els),
    case {xml:get_tag_attr_s("xmlns", XEl), xml:get_tag_attr_s("type", XEl)} of
	{?NS_XDATA, "cancel"} ->
	    {result, []};
	{?NS_XDATA, "submit"} ->
	    XData = jlib:parse_xdata_submit(XEl),
	    invalid =/= XData,
	    JidUrl = get_attr("jidurl", XData, "false"),
	    HashUrl = get_attr("hashurl", XData, "false"),
	    XML = get_attr("xml", XData, "false"),
	    Avatar = get_attr("avatar", XData, "false"),
	    Icon = get_attr("icon", XData, "disabled"),
	    iq_set_register_info(From, Host, to_bool(JidUrl), to_bool(HashUrl), to_bool(XML), to_bool(Avatar), Icon, Lang)
    end.

iq_get_vcard(Lang) ->
    [{xmlelement, "FN", [],
      [{xmlcdata, "ejabberd/mod_webpresence"}]},
     {xmlelement, "URL", [],
      [{xmlcdata,
	"http://ejabberd.jabber.ru/mod_webpresence"}]},
     {xmlelement, "DESC", [],
      [{xmlcdata, translate:translate(Lang, "ejabberd web presence module\n"
                                      "Copyright (c) 2006-2007 Igor Goryachev")}]}].

get_wp(LUser, LServer) ->
    LUS = {LUser, LServer},
    case catch mnesia:dirty_read(webpresence, LUS) of
        {'EXIT', _Reason} -> 
	    #webpresence{};
        [] -> 
	    #webpresence{};
	[WP] when is_record(WP, webpresence) ->
	    WP
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
get_presences({show, LUser, LServer, LResource}) ->
    Rs = get_presences({sorted, LUser, LServer}),
    {value, R} = lists:keysearch(LResource, 2, Rs),
    R#presence.show;
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

show_presence({image_no_check, Theme, Pr}) ->
    Dir = get_pixmaps_directory(),
    Image = Pr ++ ".{gif,png,jpg}",
    [First | _Rest] = filelib:wildcard(filename:join([Dir, Theme, Image])),
    Mime = string:substr(First, string:len(First) - 2, 3),
    {ok, Content} = file:read_file(First),
    {200, [{"Content-Type", "image/" ++ Mime}], binary_to_list(Content)};

show_presence({image, WP, LUser, LServer}) ->
    Icon = WP#webpresence.icon,
    "disabled" =/= Icon,
    Pr = get_presences({show, LUser, LServer}),
    show_presence({image_no_check, Icon, Pr});

show_presence({image, WP, LUser, LServer, Theme}) ->
    "disabled" =/= WP#webpresence.icon,
    Pr = get_presences({show, LUser, LServer}),
    show_presence({image_no_check, Theme, Pr});

show_presence({image_res, WP, LUser, LServer, LResource}) ->
    Icon = WP#webpresence.icon,
    "disabled" =/= Icon,
    Pr = get_presences({show, LUser, LServer, LResource}),
    show_presence({image_no_check, Icon, Pr});

show_presence({image_res, WP, LUser, LServer, Theme, LResource}) ->
    "disabled" =/= WP#webpresence.icon,
    Pr = get_presences({show, LUser, LServer, LResource}),
    show_presence({image_no_check, Theme, Pr});

show_presence({xml, WP, LUser, LServer}) ->
    true = WP#webpresence.xml,
    Presence_xml = xml:element_to_string(get_presences({xml, LUser, LServer})),
    {200, [{"Content-Type", "text/xml; charset=utf-8"}], ?XML_HEADER ++ Presence_xml};

show_presence({avatar, WP, LUser, LServer}) ->
    true = WP#webpresence.avatar,
    [{_, Module, Function, _Opts}] = ets:lookup(sm_iqtable, {?NS_VCARD, LServer}),
    JID = jlib:make_jid(LUser, LServer, ""),
    IQ = #iq{type = get, xmlns = ?NS_VCARD},
    IQr = Module:Function(JID, JID, IQ),
    [VCard] = IQr#iq.sub_el,
    Mime = xml:get_path_s(VCard, [{elem, "PHOTO"}, {elem, "TYPE"}, cdata]),
    BinVal = xml:get_path_s(VCard, [{elem, "PHOTO"}, {elem, "BINVAL"}, cdata]),
    Photo = jlib:decode_base64(BinVal),
    {200, [{"Content-Type", Mime}], Photo};

show_presence({image_example, Theme, Show}) ->
    Dir = get_pixmaps_directory(),
    Image = Show ++ ".{gif,png,jpg}",
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

process(LocalPath, _Request) ->
    case catch process2(LocalPath, _Request) of
	{'EXIT', _Reason} ->
	    {404, [], make_xhtml([?XC("h1", "Not found")])};
	Res ->
	    Res
    end.

process2([], _Request) ->
    Title = [?XC("title", "Web Presence")],
    Link_themes = [?AC("themes", "Icon Themes")],
    Body = [?XC("h1", "Web Presence")] ++ Link_themes,
    make_xhtml(Title, Body);

process2(["themes"], _Request) ->
    Title = [?XC("title", "Icon Themes")],
    Themes = available_themes(list),
    Icon_themes = themes_to_xhtml(Themes),
    Body = [?XC("h1", "Icon Themes")] ++ Icon_themes,
    make_xhtml(Title, Body);

process2(["image", Theme, Show], _Request) ->
    Args = {image_example, Theme, Show},
    show_presence(Args);

process2(["jid", User, Server | Tail], _Request) ->
    serve_web_presence(jid, User, Server, Tail);

process2(["hash", Hash | Tail], _Request) ->
    [Pr] = mnesia:dirty_index_read(webpresence, Hash, #webpresence.hashurl),
    {User, Server} = Pr#webpresence.us,
    serve_web_presence(hash, User, Server, Tail);

%% Compatibility with old mod_presence
process2([User, Server | Tail], _Request) ->
    serve_web_presence(jid, User, Server, Tail).


serve_web_presence(TypeURL, User, Server, Tail) ->
    LServer = jlib:nameprep(Server),
    true = lists:member(LServer, ?MYHOSTS),
    LUser = jlib:nodeprep(User),
    WP = get_wp(LUser, LServer),
    case TypeURL of
	jid -> true = WP#webpresence.jidurl;
	hash -> false =/= WP#webpresence.hashurl
    end,
    Args = case Tail of
	       ["image"] -> 
		   {image, WP, LUser, LServer};
	       ["image", Theme] -> 
		   {image, WP, LUser, LServer, Theme};
	       ["image", "res", Resource] -> 
		   {image_res, WP, LUser, LServer, Resource};
	       ["image", Theme, "res", Resource] -> 
		   {image_res, WP, LUser, LServer, Theme, Resource};
	       ["xml"] -> 
		   {xml, WP, LUser, LServer};
	       ["avatar"] -> 
		   {avatar, WP, LUser, LServer}
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
    Select = [{{webpresence, {'$1', Host}, '$2', '$3', '$4', '$5', '$6'}, [], ['$$']}],
    mnesia:dirty_select(webpresence, Select).

make_users_table(Records, Lang) ->
    TList = lists:map(
	      fun([User, HashUrl, JIDUrl, XML, Avatar, Icon]) ->
		      ?XE("tr",
			  [?XE("td", [?AC("../user/"++User++"/", User)]),
			   ?XC("td", atom_to_list(JIDUrl)),
			   ?XC("td", hashurl_out(HashUrl)),
			   ?XC("td", atom_to_list(XML)),
			   ?XC("td", atom_to_list(Avatar)),
			   ?XC("td", Icon)])
	      end, Records),
    [?XE("table",
	 [?XE("thead",
	      [?XE("tr",
		   [?XCT("td", "User"),
		    ?XCT("td", "JID"),
		    ?XCT("td", "Hash"),
		    ?XCT("td", "XML"),
		    ?XCT("td", "Avatar"),
		    ?XCT("td", "Icon")
		   ])]),
	  ?XE("tbody", TList)])].


%%%--------------------------------
%%% Update table schema and content from older versions
%%%--------------------------------

update_table() ->
    case catch mnesia:table_info(presence_registered, size) of
	Size when is_integer(Size) -> catch migrate_data_mod_presence(Size);
	_ -> ok
    end.

migrate_data_mod_presence(Size) ->
    Migrate = fun(Old, S) ->
		      {presence_registered, {US, _Host}, XML, Icon} = Old,
		      New = #webpresence{us = US,
					 hashurl = false,
					 jidurl = true,
					 xml = list_to_atom(XML),
					 avatar = false,
					 icon = Icon},
		      mnesia:write(New),
		      mnesia:delete_object(Old),
		      S-1
	      end,
    F = fun() -> mnesia:foldl(Migrate, Size, presence_registered) end,
    {atomic, 0} = mnesia:transaction(F),
    {atomic, ok} = mnesia:delete_table(presence_registered).
