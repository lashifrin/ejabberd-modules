%%
% Implémentation d'un pont PubSub-AtomPub
% A partir un noeud pubsub (?ROOTNAME)
%  - Le service document va prendre tous les noeuds fils et les présenter sous forme de collection
%  - Chacune de ces collections publiera l'interface Atom, pour ajouter/supprimer/editer des pubsub_item sous forme d'entries
% Ne gère que les entries et pas d'autre type de media.
% 
% Authentification : compte jabber sur le domaine
% Url de service : http://server/{DOMAIN}/{USER}/{COLLECTION}/{ENTRY}
% S'appuie sur l'arbo pubsub /home/{DOMAIN}/{USER}/{NODE}/{ITEM}

-module(atom_pubsub).
-author('eric@ohmforce.com').
-include("ejabberd.hrl").
-include("jlib.hrl").
-include("yaws_api.hrl").
-include("pubsub.hrl").
-include("ejabberd_http.hrl").

-export([process/2]).

-define(PUBSUB(Domain), "pubsub."++Domain).

-define(ROOTNODE(Domain, User),["home", Domain, User]).
-define(ATOMNODE(Domain, User,Collection), ["home", Domain, User, Collection]).
-define(ENTRYURL(Domain,User, Collection, Id), ?BASEURL(Domain,User, Collection)++"/"++Id).
-define(BASEURL(Domain, User, Collection), "http://localhost:5280/atom/"++Domain++"/"++ User ++ "/"++Collection).

process([Domain|_]=LocalPath,  #request{auth = Auth} = Request)->
	case get_auth(Auth) of
	%%make sure user belongs to pubsub domain
	{User, Domain} ->
	    out(Request, Request#request.method, LocalPath,User);
	_ ->
	    out(Request, Request#request.method, LocalPath,undefined)
    end;


process(_LocalPath, _Request)-> error(404).

error(404)->
	{404, [], "Not Found"};
error(500)->
	{500, [], "Internal server error"};
error(401)->
	{401, [{"WWW-Authenticate", "basic realm=\"ejabberd\""}],"Unauthorized"};
error(Code)->
	{Code, [], ""}.
success(200)->
	{200, [], ""}.

out(_Args, 'POST', [_,_, _], undefined) ->error(401);
out(_Args, 'PUT', [_,_, _], undefined) ->error(401);	
out(_Args, 'DELETE', [_,_, _], undefined) ->error(401);


%% Service document
out(_Args, 'GET', [Domain, UserNode], _User) ->
	Collections = mnesia:dirty_select(
	       pubsub_node,
	       [{#pubsub_node{parentid = {?PUBSUB(Domain), ?ROOTNODE(Domain, UserNode)}, 
						nodeid={?PUBSUB(Domain), ?ATOMNODE(Domain, UserNode,'$1')},_ = '_'},
		 [],
		 ['$1']}]),
	
	{200, [{"Content-Type", "application/atomsvc+xml"}], "<?xml version=\"1.0\" encoding=\"utf-8\"?>" 
				++	xml:element_to_string(service(Domain, UserNode, Collections))};

%% Collection

out(_Args, 'GET', [Domain, User, Collection], _User) -> 
	Items = lists:sort(fun(X,Y)->
			{_,DateX} = X#pubsub_item.modification,
			{_,DateY} = Y#pubsub_item.modification,
			DateX > DateY
		end, mod_pubsub:get_items(?PUBSUB(Domain), ?ATOMNODE(Domain, User,Collection))),
	XMLEntries= [item_to_entry(Collection, Entry)||
		Entry <-  Items], 
	{200, [{"Content-Type", "application/atom+xml"}], "<?xml version=\"1.0\" encoding=\"utf-8\"?>" 
		++	xml:element_to_string(collection(Collection, ?BASEURL(Domain,User,Collection),{date(),time()}, User, "", XMLEntries))};

				
%% New Member

out(Args, 'POST', [Domain,User, Collection], User) -> 
	%H = Args#arg.headers,
	%Slug = case lists:keysearch("Slug",3,H#headers.other) of false -> false ; {value, {_,_,_,_,Value}} -> Value end,
	%%?DEBUG("Headers (other) : ~p et Slug :~p~n",[H#headers.other, Slug]),
	Payload = xml_stream:parse_element(Args#request.data),
	Id = uniqid(false),
	case mod_pubsub:publish_item(?PUBSUB(Domain), Domain, ?ATOMNODE(Domain, User,Collection), jlib:make_jid(User,Domain, ""), Id, [Payload]) of
		{result, []} ->
			{201, [{"location", ?ENTRYURL(Domain,User, Collection, Id)}], ""};
		{error, Error} ->
			?DEBUG("~p~n",[Error]),
			error(500)
		end;
out(_Args, 'POST', [_, _, _], _) ->
	{status, 401};
			
%% Atom doc
out(_Args, 'GET', [Domain, UserNode, Collection, Member], _User) -> 
	case catch mnesia:dirty_read(pubsub_item, {Member, {?PUBSUB(Domain), ?ATOMNODE(Domain, UserNode,Collection)}}) of
		{aborted, Reason} ->
			?DEBUG("~p~n",[Reason]),
			error(404);
		[Item] ->
			{200, [{"Content-Type",  "application/atom+xml"}], "<?xml version=\"1.0\" encoding=\"utf-8\"?>" 
					++ xml:element_to_string(item_to_entry(Collection, Item))};
		[] ->
			error(404)
		end;
		

%% Update doc
out(Args, 'PUT', [Domain,User, Collection, Member], User) -> 
	Payload = xml_stream:parse_element(Args#request.data),
	case mod_pubsub:publish_item(?PUBSUB(Domain), Domain, ?ATOMNODE(Domain, User,Collection), jlib:make_jid(User,Domain, ""), Member, [Payload]) of
		{result, _Result} -> 
			success(200);
		{error, {xmlelement, "error", [{"code",Code},_],_}} ->
			?DEBUG("Code : ~p~n",[Code]),
			error(code);
		{error, Error} ->
			?DEBUG("~p~n",[Error]),
			error(500)
		end;
%%
out(_Args, 'PUT',Url, User) ->
	?DEBUG("Put forbidden (~p) : ~p~n",[User,Url]),
	error(401);

out(_Args, 'DELETE', [Domain,User, Collection, Member], User) ->
	?DEBUG("Delete called on (~p) : ~p~n",[Collection, Member]),
	case mod_pubsub:delete_item(?PUBSUB(Domain), ?ATOMNODE(Domain, User,Collection), jlib:make_jid(User,Domain, ""), Member) of
		{result, _Result} -> 
			success(200);
		{error, {xmlelement, "error", [{"code",Code},_],_}} ->
			?DEBUG("PubSub Code : ~p~n",[Code]),
			error(code);
		{error, Code1} ->
			?DEBUG("PubSub Code : ~p~n",[Code1]),
			error(500)
		end;

out(_Args, 'DELETE',Url, User) ->
		?DEBUG("Delete forbidden (~p) : ~p~n",[User,Url]),
		error(401);	
		
out(_, _, _, _) ->
	error(400).



item_to_entry(Collection,#pubsub_item{itemid={Id,_}, payload=[Entry]}=Item)->
	item_to_entry(Collection, Id, Entry, Item).
item_to_entry(Collection, Id, Entry, #pubsub_item{modification={_, Secs}, itemid={Id, {_,?ATOMNODE(Domain, User, _)}}}) ->
	{xmlelement, "entry", Attrs, SubEl}=Entry,
	Date = calendar:now_to_local_time(Secs),
	SubEl2=[{xmlelement, "app:edited", [], [{xmlcdata, w3cdtf(Date)}]},
			{xmlelement, "link",[{"rel", "edit"}, 
			{"href", ?ENTRYURL(Domain,User, Collection, Id)}],[] }, 
			{xmlelement, "id", [],[{xmlcdata, Id}]}
			| SubEl],
	{xmlelement, "entry", Attrs, SubEl2}.

collection(Title, Link, Updated, Author, _Id, Entries)->
	{xmlelement, "feed", [{"xmlns", "http://www.w3.org/2005/Atom"}, {"xmlns:app", "http://www.w3.org/2007/app"}], [
		{xmlelement, "title", [],[{xmlcdata, Title}]},
		{xmlelement, "updated", [],[{xmlcdata, w3cdtf(Updated)}]},
		{xmlelement, "link", [{"href", Link}], []},
		{xmlelement, "author", [], [
			{xmlelement, "name", [], [{xmlcdata,Author}]}
		]},
		{xmlelement, "title", [],[{xmlcdata, Title}]} | 
		Entries
	]}.

service(Domain, User, Collections)->
	{xmlelement, "service", [{"xmlns", "http://www.w3.org/2007/app"},
							{"xmlns:atom", "http://www.w3.org/2005/Atom"},
							{"xmlns:app", "http://www.w3.org/2007/app"}],[
		{xmlelement, "workspace", [],[
			{xmlelement, "atom:title", [],[{xmlcdata,"Feed for "++User++"@"++Domain}]} | 
			lists:map(fun(Collection)->
				{xmlelement, "collection", [{"href", ?BASEURL(Domain,User, Collection)}], [
					{xmlelement, "atom:title", [], [{xmlcdata, Collection}]}
				]}
				end, Collections)
		]}
	]}.

%%% lifted from ejabberd_web_admin
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

% Code below is taken (with some modifications) from the yaws webserver, which
% is distributed under the folowing license:
%
% This software (the yaws webserver) is free software.
% Parts of this software is Copyright (c) Claes Wikstrom <klacke@hyber.org>
% Any use or misuse of the source code is hereby freely allowed.
%
% 1. Redistributions of source code must retain the above copyright
%    notice as well as this list of conditions.
%
% 2. Redistributions in binary form must reproduce the above copyright
%    notice as well as this list of conditions.
%%% Create W3CDTF (http://www.w3.org/TR/NOTE-datetime) formatted date
%%% w3cdtf(GregSecs) -> "YYYY-MM-DDThh:mm:ssTZD"
%%%
uniqid(false)->
	{T1, T2, T3} = now(),
    lists:flatten(io_lib:fwrite("~.16B~.16B~.16B", [T1, T2, T3]));
uniqid(Slug) ->
	Slut = string:to_lower(Slug),
	S = string:substr(Slut, 1, 9),
    {T1, T2, T3} = now(),
    lists:flatten(io_lib:fwrite("~s-~.16B~.16B", [S, T2, T3])).

w3cdtf(Date) -> %1   Date = calendar:gregorian_seconds_to_datetime(GregSecs),
    {{Y, Mo, D},{H, Mi, S}} = Date,
    [UDate|_] = calendar:local_time_to_universal_time_dst(Date),
    {DiffD,{DiffH,DiffMi,_}}=calendar:time_difference(UDate,Date),
    w3cdtf_diff(Y, Mo, D, H, Mi, S, DiffD, DiffH, DiffMi). 

%%%  w3cdtf's helper function
w3cdtf_diff(Y, Mo, D, H, Mi, S, _DiffD, DiffH, DiffMi) when DiffH < 12,  DiffH /= 0 ->
    i2l(Y) ++ "-" ++ add_zero(Mo) ++ "-" ++ add_zero(D) ++ "T" ++
        add_zero(H) ++ ":" ++ add_zero(Mi) ++ ":"  ++
        add_zero(S) ++ "+" ++ add_zero(DiffH) ++ ":"  ++ add_zero(DiffMi);

w3cdtf_diff(Y, Mo, D, H, Mi, S, DiffD, DiffH, DiffMi) when DiffH > 12,  DiffD == 0 ->
    i2l(Y) ++ "-" ++ add_zero(Mo) ++ "-" ++ add_zero(D) ++ "T" ++
        add_zero(H) ++ ":" ++ add_zero(Mi) ++ ":"  ++
        add_zero(S) ++ "+" ++ add_zero(DiffH) ++ ":"  ++
        add_zero(DiffMi);

w3cdtf_diff(Y, Mo, D, H, Mi, S, DiffD, DiffH, DiffMi) when DiffH > 12,  DiffD /= 0, DiffMi /= 0 ->
    i2l(Y) ++ "-" ++ add_zero(Mo) ++ "-" ++ add_zero(D) ++ "T" ++
        add_zero(H) ++ ":" ++ add_zero(Mi) ++ ":"  ++
        add_zero(S) ++ "-" ++ add_zero(23-DiffH) ++
        ":" ++ add_zero(60-DiffMi);

w3cdtf_diff(Y, Mo, D, H, Mi, S, DiffD, DiffH, DiffMi) when DiffH > 12,  DiffD /= 0, DiffMi == 0 ->
   i2l(Y) ++ "-" ++ add_zero(Mo) ++ "-" ++ add_zero(D) ++ "T" ++
        add_zero(H) ++ ":" ++ add_zero(Mi) ++ ":"  ++
        add_zero(S) ++ "-" ++ add_zero(24-DiffH) ++
        ":" ++ add_zero(DiffMi); 

w3cdtf_diff(Y, Mo, D, H, Mi, S, _DiffD, DiffH, _DiffMi) when DiffH == 0 ->
    i2l(Y) ++ "-" ++ add_zero(Mo) ++ "-" ++ add_zero(D) ++ "T" ++
        add_zero(H) ++ ":" ++ add_zero(Mi) ++ ":"  ++
        add_zero(S) ++ "Z".

add_zero(I) when integer(I) -> add_zero(i2l(I));
add_zero([A])               -> [$0,A];
add_zero(L) when list(L)    -> L. 

i2l(I) when integer(I) -> integer_to_list(I);
i2l(L) when list(L)    -> L.


