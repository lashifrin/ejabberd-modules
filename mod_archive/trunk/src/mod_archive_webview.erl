%%%----------------------------------------------------------------------
%%% File    : mod_archive_webview.erl
%%% Author  : Olivier Goffart <ogoffart at kde dot org>
%%% Purpose : Online viewer of message archive.  (to be used with mod_archive_odbc)
%%% Created :
%%% Id      :
%%%----------------------------------------------------------------------

-module(mod_archive_webview).
-author('ogoffart@kde.org').

-export([
	 process/2
	]).

-include("ejabberd.hrl").
-include("jlib.hrl").
-include("web/ejabberd_http.hrl").

-include("web/ejabberd_web_admin.hrl"). %for all the defines

-define(LINK(L) , "/archive/" ++ L).
%-define(P(Els), ?XE("p", Els)).
-define(PC(Text), ?XE("p", [?C(Text)])).
-define(PCT(Text), ?PC(?T(Text))).


-define(MYDEBUG(Format, Args),
        io:format("D(~p:~p:~p) : " ++ Format ++ "~n",
                  [calendar:local_time(), ?MODULE, ?LINE] ++ Args)).


%%%----------------------------------------------------------------------
%%% REQUEST HANDLERS
%%%----------------------------------------------------------------------

%process([], Request) -> process2([], Request, {}).

process(["style.css"], _) ->
    {200,[], "
#navigation li { list-style:none; display:inline;  }
.message_from, .message_to { margin:0; padding:0; }
.message_from .time { color:#BD2134; font-weight:bold; }
.message_from .jid  { color:#BD2134; font-weight:bold; }
.message_to   .time { color:#1E6CC6; font-weight:bold; }
.message_to   .jid  { color:#1E6CC6; font-weight:bold; }
"};

process(Path, #request{auth = Auth} = Request) ->
    ?MYDEBUG("Requested ~p ~p", [Path, Request]),
    
    case get_auth(Auth) of
        {User, Server} ->
            process2(Path, Request, {User, Server});
        unauthorized ->
            {401, [{"WWW-Authenticate", "basic realm=\"ejabberd-archives\""}],
                ejabberd_web:make_xhtml([{xmlelement, "h1", [],
                                               [{xmlcdata, "401 Unauthorized"}]}])}
    end.
   

%process2(["config" | tail], #request{lang = Lang } = Request , {User, Server}) ->

process2(["config" ], #request{lang = Lang } = Request , {User, Server}) ->
    make_xhtml(?T("Config"),
        [?XE("h3", [?CT("Global Settings")]) ] ++ global_config_form({User, Server}, Lang) ++
        [?XE("h3", [?CT("Specific Contact Settings")]) ] ++ contact_config_form({User, Server}, Lang) , Lang);
    
process2(["contact"], #request{lang = Lang } = Request , US) ->
    make_xhtml(?T("Contact List"), [
                           ?XE("ul", lists:map( fun({Node,Server,Count}) -> 
                                                    With = jlib:jid_to_string({Node,Server,""}),
                                                    ?LI([?AC(?LINK("contact/" ++ With), With ) , ?C(" (" ++ Count  ++")")] ) end,
                                                get_contacts(US)))
               ], Lang);
               
               
process2(["contact" , Jid], #request{lang = Lang } = Request , US) ->
    make_xhtml(?T("Chat with ") ++ Jid, contact_config(Jid,US,Lang) ++
                           [?XE("ul", lists:map( fun({Id, Node, Server, Resource, Utc, Subject }) -> 
                                                    With = jlib:jid_to_string({Node,Server,Resource}),
                                                    ?LI([?AC(?LINK("show/" ++ integer_to_list(Id)), "On " ++ Utc ++ " with " ++ With ++ " -> " ++ Subject  )] ) end,
                                                get_collection_list(jlib:string_to_jid(Jid), US)))
               ], Lang);

process2(["show" , Id], #request{lang = Lang } = Request , US) ->
    { With, Subject, List } = get_collection(Id, US),
    make_xhtml(?T("Chat With ") ++ jlib:jid_to_string(With) ++ ?T(" : ") ++ Subject,
               lists:map(fun(Msg) -> format_message(Msg,With, US) end, List)
               %++[?X("hr"), ?XEA("form",[{"action",?LINK("edit/" ++ integer_to_list(Id))},{"metohd","post"}],...) ]
               , Lang);
   
    
process2(_, #request{lang = Lang } = Request , {User, Server}) ->
    make_xhtml(?T("404 File not found"),[], Lang).

%------------------------------

make_xhtml(Title, Els, Lang) ->
    ?MYDEBUG("make_xhtml ~p", [Els]),
    
    {200, [html],
        {xmlelement, "html", [{"xmlns", "http://www.w3.org/1999/xhtml"},
                {"xml:lang", Lang},
                {"lang", Lang}],
        [{xmlelement, "head", [],
        [?XE("title",  [?C(Title) , ?CT(" - ejabberd Web Archive Viewer")]),
        {xmlelement, "meta", [{"http-equiv", "Content-Type"},
                    {"content", "text/html; charset=utf-8"}], []},
        {xmlelement, "link", [{"href", ?LINK("style.css")},
                    {"type", "text/css"},
                    {"rel", "stylesheet"}], []}]},
        ?XE("body",
        [?XAE("div", [{"id", "container"}],
              [?XAE("div", [{"id", "header"}],
                    [?XE("h1", [?CT("Archives Viewer")])]),
               ?XAE("div", [{"id", "navigation"}],
                    [?XE("ul",
                     [?LI([?ACT(?LINK("config"), "Config")]), ?C(" "),
                      ?LI([?ACT(?LINK("contact"), "Browse")])])]), ?C(" "),
               ?XAE("div", [{"id", "content"}], [ ?XE("h2", [?C(Title)]) | Els])])])]}}.


get_auth(Auth) ->
    case Auth of
        {SJID, P} ->
            case jlib:string_to_jid(SJID) of
                error ->
                    unauthorized;
                #jid{user = U, server = S} ->
                    case ejabberd_auth:check_password(U, S, P) of
                        true ->
                            {U, S};
                        false ->
                            unauthorized
                    end
            end;
         _ ->
            unauthorized
    end.

%------------------------


format_message({ Utc, Dir, Body } ,{WithU,WithS,WithR}, {LUser,LServer} ) ->
    {From, Class} = case Dir of 
        0 -> { jlib:jid_to_string({WithU,WithS,WithR}) , "message_from" } ;
        1 -> { jlib:jid_to_string({LUser,LServer,""}) , "message_to" } 
    end,
    ?XAE("p", [{"class", Class}] , [ ?XAE("span", [{"class","time"}], [?C("["++Utc++"]")]), ?C(" "),
                                   ?XAE("span", [{"class","jid"}], [?C(From)]), ?C(": "),
                                   ?XAE("span", [{"class","message_body"}], [?C(Body)])]).

contact_config(Jid,{LUser,LServer},Lang) ->
    %run_sql_transaction(LServer, fun() -> run_sql_query("") end)
    %[?XE("p",[?CT("Automatic archive with this contact is " + Au   ), ].
    [].


select_element(Name, List, Value) ->
    ?XAE("select",[{"name",Name}],lists:map( 
        fun({Key,Text}) -> ?XAE("option", 
                            case Key of
                                Value -> [{"value",integer_to_list(Value)},{"selected","selected"}];
                                _ -> [{"value",integer_to_list(Key)}]
                            end, [?C(Text)]) end, List)).
                            
table_element(Rows) ->
    ?XE("table",lists:map(fun(Cols)-> ?XE("tr", lists:map(fun(Ct)-> ?XE("td",Ct) end, Cols)) end, Rows)).

global_config_form({LUser,LServer},Lang) ->
    {selected, _, [{Save,Expire,Otr,Method_auto,Method_local,Method_manual,Auto_save}]} =
         run_sql_transaction(LServer, fun() -> run_sql_query(
            "SELECT save,expire,otr,method_auto,method_local,method_manual,auto_save"
            " FROM archive_global_prefs"
            " WHERE us = " ++ get_us_escaped({LUser,LServer}) ) end),
    MethodList = [ {-1,?T("--Undefined--")}, {0,?T("Prefer")}, {1,?T("Concede")}, {2,?T("Forbid")} ],
    [?XAE("form",[{"action",?LINK("config/submit/global")}],[table_element([[
            [?XE("label",[?CT("Save: "), select_element("global_save",[{-1,?T("--Default--")},{1,?T("Enabled")},{0,?T("Disabled")}],decode_integer(Save))])],
            [?XE("label",[?CT("Expire: "), ?INPUT("text","global_expire",integer_to_list(decode_integer(Expire)))])],
            [?XE("label",[?CT("Otr: "), select_element("global_otr",[{-1,?T("--Undefined--")},
                                                                        {0,?T("Approve")},
                                                                        {1,?T("Concede")},
                                                                        {2,?T("Forbid")},
                                                                        {3,?T("Oppose")},
                                                                        {4,?T("Prefer")},
                                                                        {5,?T("Require")} ],decode_integer(Otr))])],
            [?XE("label",[?CT("Auto Method: "), select_element("global_method_auto", MethodList,decode_integer(Method_auto))])],
            [?XE("label",[?CT("Local Method: "), select_element("global_method_local", MethodList,decode_integer(Method_local))])],
            [?XE("label",[?CT("Manual Method: "), select_element("global_method_manual", MethodList,decode_integer(Method_manual))])],
            [?XE("label",[?CT("Auto Save "), select_element("global_method_auto",
                                             [{-1,?T("--Default--")},{1,?T("Enabled")},{0,?T("Disabled")}],decode_integer(Auto_save))])],
            [?INPUT("submit","global_modify",?T("Modify"))]
       ]])])].

    
contact_config_form({LUser,LServer},Lang) ->
%     {selected, _, List} =
%          run_sql_transaction(LServer, fun() -> run_sql_query(
%             "SELECT with_user,with_server,with_resource,save,expire,otr"
%             " FROM archive_jid_prefs"
%             " WHERE us = " ++ get_us_escaped({LUser,LServer}) ) end),
    [?PCT("TODO")].


%------------------------

get_contacts({LUser, LServer}) ->
    Fun = fun() ->
        {selected, _ , Contacts} = run_sql_query("SELECT with_user,with_server,COUNT(*)"
                                                 " FROM archive_collections"
                                                 " WHERE us = " ++ get_us_escaped({LUser,LServer}) ++ 
                                                 " GROUP BY with_user,with_server"),
        Contacts end,
    run_sql_transaction(LServer, Fun).

get_collection_list(Jid, {LUser, LServer}) ->
    {WithU, WithS, _} = get_jid_escaped(Jid),
    Fun = fun() ->
        {selected, _ , List} = run_sql_query("SELECT id,with_user,with_server,with_resource,utc,subject"
                                                 " FROM archive_collections"
                                                 " WHERE us = " ++ get_us_escaped({LUser,LServer}) ++ 
                                                 "  AND with_user = " ++ WithU ++
                                                 "  AND with_server = " ++ WithS),
        List end,
    run_sql_transaction(LServer, Fun).
    
get_collection(Id,{LUser,LServer}) ->
    Fun = fun() ->
         {selected, _ , [{WithU, WithS, WithR, Subject}] } = run_sql_query(
                            "SELECT with_user,with_server,with_resource,subject"
                            " FROM archive_collections"
                            " WHERE id = '" ++ ejabberd_odbc:escape(Id) ++ "'" 
                            "  AND us = " ++ get_us_escaped({LUser,LServer})),
                                                 
         {selected, _ , List} = run_sql_query("SELECT utc,dir,body"
                                                 " FROM archive_messages"
                                                 " WHERE coll_id = '" ++ ejabberd_odbc:escape(Id) ++ "'"),
        { {WithU,WithS,WithR} , Subject , List} end,
    run_sql_transaction(LServer, Fun).
    

%------------------------
% from mod_archive_odbc
run_sql_query(Query) ->
    %%?MYDEBUG("running query: ~p", [lists:flatten(Query)]),
    case catch ejabberd_odbc:sql_query_t(Query) of
        {'EXIT', Err} ->
            ?ERROR_MSG("unhandled exception during query: ~p", [Err]),
            exit(Err);
        {error, Err} ->
            ?ERROR_MSG("error during query: ~p", [Err]),
            throw({error, Err});
        aborted ->
            ?ERROR_MSG("query aborted ~p", [Query]),
            throw(aborted);
        R -> ?MYDEBUG("query result: ~p", [R]),
            R
    end.

run_sql_transaction(LServer, F) ->
    DBHost = gen_mod:get_module_opt(LServer, ?MODULE, db_host, LServer),
    case ejabberd_odbc:sql_transaction(DBHost, F) of
        {atomic, R} ->
            ?MYDEBUG("succeeded transaction: ~p", [R]),
            R;
        {error, Err} -> {error, Err};
        E ->
            ?ERROR_MSG("failed transaction: ~p, stack: ~p", [E, process_info(self(),backtrace)]),
            {error, ?ERR_INTERNAL_SERVER_ERROR}
    end.
    
get_us_escaped({LUser, LServer}) ->
    "'" ++ ejabberd_odbc:escape(LUser ++ "@" ++ LServer) ++ "'".

get_jid_escaped({LUser, LServer, LResource}) ->
    {"'" ++ ejabberd_odbc:escape(LUser), "'" ++ ejabberd_odbc:escape(LServer),
     "'" ++ ejabberd_odbc:escape(LResource)};

get_jid_escaped(#jid{luser = LUser, lserver = LServer, lresource=LResource}) ->
    {"'" ++ ejabberd_odbc:escape(LUser) ++ "'", "'" ++ ejabberd_odbc:escape(LServer) ++ "'",
     "'" ++ ejabberd_odbc:escape(LResource) ++ "'"}.

decode_integer(Val) when is_integer(Val) ->
    Val;
decode_integer(null) ->
    -1;
decode_integer(Val) ->
    list_to_integer(Val).
