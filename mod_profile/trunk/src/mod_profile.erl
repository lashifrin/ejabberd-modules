%%%----------------------------------------------------------------------
%%% File    : mod_profile.erl
%%% Author  : Magnus Henoch <henoch@dtek.chalmers.se>
%%% Purpose : XEP-0154 User Profile
%%% Created : 22 Oct 2006 by Magnus Henoch <henoch@dtek.chalmers.se>
%%% Id      : $Id$
%%%----------------------------------------------------------------------

-module(mod_profile).
-author('henoch@dtek.chalmers.se').

-behaviour(gen_mod).

-export([start/2, stop/1,
	 process_sm_iq/3,
	 get_sm_features/5,
	 remove_user/2]).

-include("ejabberd.hrl").
-include("jlib.hrl").

-record(profile, {us, fields}).

-define(NS_PROFILE, "http://jabber.org/protocol/profile").

start(Host, Opts) ->
    mnesia:create_table(profile, [{disc_only_copies, [node()]},
				  {attributes, record_info(fields, profile)}]),
    ejabberd_hooks:add(remove_user, Host, ?MODULE, remove_user, 50),
    IQDisc = gen_mod:get_opt(iqdisc, Opts, one_queue),
    gen_iq_handler:add_iq_handler(ejabberd_sm, Host, ?NS_PROFILE,
				  ?MODULE, process_sm_iq, IQDisc),
    ejabberd_hooks:add(disco_sm_features, Host, ?MODULE, get_sm_features, 50).

stop(Host) ->
    ejabberd_hooks:delete(disco_sm_features, Host, ?MODULE, get_sm_features, 50),
    ejabberd_hooks:delete(remove_user, Host, ?MODULE, remove_user, 50),
    gen_iq_handler:remove_iq_handler(ejabberd_sm, Host, ?NS_PROFILE).

process_sm_iq(From, To, #iq{type = Type, sub_el = SubEl} = IQ) ->
    case Type of
	set ->
	    #jid{luser = LUser, lserver = LServer} = From,
	    case lists:member(LServer, ?MYHOSTS) of
		true ->
		    {xmlelement, _, _, SubSubEls} = SubEl,
		    case [El || {xmlelement, Name, _Attrs, _Els} = El <- xml:remove_cdata(SubSubEls),
				Name == "x"] of
			[XData] ->
			    case set_profile(LUser, LServer, XData) of
				ok ->
				    IQ#iq{type = result, sub_el = []};
				{error, Error} ->
				    IQ#iq{type = error, sub_el = [SubEl, Error]}
			    end;
			_ ->
			    IQ#iq{type = error, sub_el = [SubEl, ?ERR_BAD_REQUEST]}
		    end;
		false ->
		    IQ#iq{type = error, sub_el = [SubEl, ?ERR_NOT_ALLOWED]}
	    end;
	get ->
	    #jid{luser = LUser, lserver = LServer} = To,
	    US = {LUser, LServer},
	    F = fun() ->
			mnesia:read({profile, US})
		end,
	    case mnesia:transaction(F) of
		{atomic, [#profile{fields = Fields}]} ->
		    IQ#iq{type = result,
			  sub_el =
			  [{xmlelement, "x", [{"xmlns", "jabber:x:data"},
					      {"type", "result"}],
			   Fields}]};
		{atomic, []} ->
		    IQ#iq{type = error, sub_el = [SubEl, ?ERR_SERVICE_UNAVAILABLE]};
		_ ->
		    IQ#iq{type = error, sub_el = [SubEl, ?ERR_INTERNAL_SERVER_ERROR]}
	    end
    end.

get_sm_features({error, _} = Acc, _From, _To, _Node, _Lang) ->
    Acc;
get_sm_features(Acc, _From, _To, Node, _Lang) ->
    %% XXX: this will make nonexistent users seem to exist.  But
    %% mod_adhoc and mod_vcard do that already.
    case Node of
	[] ->
	    case Acc of
		{result, Features} ->
		    {result, [?NS_PROFILE | Features]};
		empty ->
		    {result, [?NS_PROFILE]}
	    end;
	_ ->
	    Acc
    end.

remove_user(User, Server) ->
    LUser = jlib:nodeprep(User),
    LServer = jlib:nameprep(Server),
    US = {LUser, LServer},
    F = fun() ->
		mnesia:delete({profile, US})
	end,
    mnesia:transaction(F).

set_profile(LUser, LServer, {xmlelement, "x", _Attrs, Els}) ->
    US = {LUser, LServer},
    F = fun() ->
		mnesia:write(#profile{us = US, fields = Els})
	end,
    case mnesia:transaction(F) of
	{atomic, _} ->
	    ok;
	_ ->
	    {error, ?ERR_INTERNAL_SERVER_ERROR}
    end.
