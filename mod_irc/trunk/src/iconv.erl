%%%----------------------------------------------------------------------
%%% File    : iconv.erl
%%% Author  : Alexey Shchepin <alexey@sevcom.net>
%%% Purpose : Interface to libiconv
%%% Created : 16 Feb 2003 by Alexey Shchepin <alexey@sevcom.net>
%%% Id      : $Id: iconv.erl 427 2005-10-25 02:19:01Z alexey $
%%%----------------------------------------------------------------------

-module(iconv).
-author('alexey@sevcom.net').
-vsn('$Revision: 427 $ ').

-behaviour(gen_server).

-export([start/0, start_link/0, convert/3]).

%% Internal exports, call-back functions.
-export([init/1,
	 handle_call/3,
	 handle_cast/2,
	 handle_info/2,
	 code_change/3,
	 terminate/2]).



start() ->
    gen_server:start({local, ?MODULE}, ?MODULE, [], []).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    case erl_ddll:load_driver(ejabberd:get_so_path(), iconv_erl) of
	ok -> ok;
	{error, already_loaded} -> ok
    end,
    Port = open_port({spawn, iconv_erl}, []),
    ets:new(iconv_table, [set, public, named_table]),
    ets:insert(iconv_table, {port, Port}),
    {ok, Port}.


%%% --------------------------------------------------------
%%% The call-back functions.
%%% --------------------------------------------------------

handle_call(_, _, State) ->
    {noreply, State}.

handle_cast(_, State) ->
    {noreply, State}.

handle_info({'EXIT', Pid, Reason}, Port) ->
    {noreply, Port};

handle_info({'EXIT', Port, Reason}, Port) ->
    {stop, {port_died, Reason}, Port};
handle_info(_, State) ->
    {noreply, State}.

code_change(OldVsn, State, Extra) ->
    {ok, State}.

terminate(_Reason, Port) ->
    Port ! {self, close},
    ok.



convert(From, To, String) ->
    [{port, Port} | _] = ets:lookup(iconv_table, port),
    Bin = term_to_binary({From, To, String}),
    BRes = port_control(Port, 1, Bin),
    binary_to_list(BRes).



