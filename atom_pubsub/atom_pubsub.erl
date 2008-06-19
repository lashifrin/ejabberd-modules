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

-export([out/1]).

-define(PUBSUB(Domain), "pubsub."++Domain).

-define(ROOTNODE(Domain, User),["home", Domain, User]).
-define(ATOMNODE(Domain, User,Collection), ["home", Domain, User, Collection]).
-define(ENTRYURL(Domain,User, Collection, Id), ?BASEURL(Domain,User, Collection)++"/"++Id).
-define(BASEURL(Domain, User, Collection), "http://localhost:5224/atom/"++Domain++"/"++ User ++ "/"++Collection).

out(Args) ->
	Url = yaws_api:request_url(Args),
	[_|Path] = string:tokens(Url#url.path, "/"),
	[Domain|_]=Path,
	Method = (Args#arg.req)#http_request.method,
	H = Args#arg.headers,
	U = case H#headers.authorization of
		{User,Pass,_Auth} ->
			case ejabberd_auth:get_password(User, Domain) of
				Pass ->
					User;
				_ ->
					undefined
			end;
		_->
			undefined
	end,
	try out(Args, Method, Path, U)
	catch
		_-> {allheaders, [{status, 500}]}
	end.

-define(SHOULD_AUTH, [{status, 401}, {header, "WWW-Authenticate: Basic realm=\"AtOhm\""}]).
%out(Args, 'GET', ["pubsub", Collection], undefined) ->?SHOULD_AUTH;			
out(_Args, 'POST', [_,_, _], undefined) ->?SHOULD_AUTH;
out(_Args, 'PUT', [_,_, _], undefined) ->?SHOULD_AUTH;	
out(_Args, 'DELETE', [_,_, _], undefined) ->?SHOULD_AUTH;


%% Service document
out(_Args, 'GET', [Domain, UserNode], _User) ->
	Collections = mnesia:dirty_select(
	       pubsub_node,
	       [{#pubsub_node{parentid = {?PUBSUB(Domain), ?ROOTNODE(Domain, UserNode)}, 
						nodeid={?PUBSUB(Domain), ?ATOMNODE(Domain, UserNode,'$1')},_ = '_'},
		 [],
		 ['$1']}]),
	
	{content, "application/atomsvc+xml", "<?xml version=\"1.0\" encoding=\"utf-8\"?>" 
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
	{content, "application/atom+xml", "<?xml version=\"1.0\" encoding=\"utf-8\"?>" 
		++	xml:element_to_string(collection(Collection, ?BASEURL(Domain,User,Collection),{date(),time()}, User, "", XMLEntries))};

				
%% New Member

out(Args, 'POST', [Domain,User, Collection], User) -> 
	H = Args#arg.headers,
	Slug = case lists:keysearch("Slug",3,H#headers.other) of false -> false ; {value, {_,_,_,_,Value}} -> Value end,
	?DEBUG("Headers (other) : ~p et Slug :~p~n",[H#headers.other, Slug]),
	Payload = xml_stream:parse_element(binary_to_list(Args#arg.clidata)),
	Id = uniqid(Slug),
	case mod_pubsub:publish_item(?PUBSUB(Domain), Domain, ?ATOMNODE(Domain, User,Collection), jlib:make_jid(User,Domain, ""), Id, [Payload]) of
		{result, []} ->
			[{status, 201}, {header, "location: "++?ENTRYURL(Domain,User, Collection, Id)}];
		{error, Error} ->
			?DEBUG("~p~n",[Error]),
			{status, 500}
		end;
out(_Args, 'POST', [_, _, _], _) ->
	{status, 401};
			
%% Atom doc
out(_Args, 'GET', [Domain, UserNode, Collection, Member], _User) -> 
	case catch mnesia:dirty_read(pubsub_item, {Member, {?PUBSUB(Domain), ?ATOMNODE(Domain, UserNode,Collection)}}) of
		{aborted, Reason} ->
			?DEBUG("~p~n",[Reason]),
			{status, 404};
		[Item] ->
			{content, "application/atom+xml", "<?xml version=\"1.0\" encoding=\"utf-8\"?>" 
					++ xml:element_to_string(item_to_entry(Collection, Item))};
		[] ->
			{status, 404}
		end;
		

%% Update doc
out(Args, 'PUT', [Domain,User, Collection, Member], User) -> 
	Payload = xml_stream:parse_element(binary_to_list(Args#arg.clidata)),
	case mod_pubsub:publish_item(?PUBSUB(Domain), Domain, ?ATOMNODE(Domain, User,Collection), jlib:make_jid(User,Domain, ""), Member, [Payload]) of
		{result, _Result} -> 
			{status, 200};
		{error, {xmlelement, "error", [{"code",Code},_],_}} ->
			?DEBUG("Code : ~p~n",[Code]),
			{status, Code};
		{error, Error} ->
			?DEBUG("~p~n",[Error]),
			{status, 500}
		end;
%%
out(_Args, 'PUT',Url, User) ->
	?DEBUG("Put forbidden (~p) : ~p~n",[User,Url]),
		{status, 401};

out(_Args, 'DELETE', [Domain,User, Collection, Member], User) ->
	case mod_pubsub:delete_item(?PUBSUB(Domain), ?ATOMNODE(Domain, User,Collection), jlib:make_jid(User,Domain, ""), Member) of
		{result, _Result} -> 
			{status, 200};
		{error, {xmlelement, "error", [{"code",Code},_],_}} ->
			?DEBUG("PubSub Code : ~p~n",[Code]),
			{status, Code};
		{error, Code1} ->
			?DEBUG("PubSub Code : ~p~n",[Code1]),
			{status, 500}
		end;

out(_Args, 'DELETE',Url, User) ->
		?DEBUG("Delete forbidden (~p) : ~p~n",[User,Url]),
		{status, 401};		
		
out(_, _, _, _) ->
	{status, 400}.



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

%%% Lifted from yaws_rss
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


