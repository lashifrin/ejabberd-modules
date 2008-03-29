%%% @author  Pablo Polvorin <pablo.polvorin@process-one.net>
%%% @doc state machine implementing the Postgres protocol.
%%%     It is composed of two process: the fsm itself and a listener
%%%     process that reads data from the socket and feeds the state machine 

-module(pgsql2_proto).

-behaviour(gen_fsm).


%% TODO: Specify own module types in connect options
%% TODO: In pquery, specify if we want the result as text or as binary
%% TODO: see commit and rollback
%% TODO: nested transacitions?
%% TODO: do_in_transaction(fun/1) ?


%% API
-export([start_link/1]).	

%% gen_fsm callbacks
-export([init/1,handle_event/3,handle_sync_event/4,handle_info/3,terminate/3,code_change/4]).

%% States
-export([
		wait_for_auth_request/3,
		wait_for_auth_response/3,
		wait_for_server_settings/3,
		wait_for_types_info/3,
		ready_for_query/3,
		wait_for_equery_response/3,
		wait_for_execute_batch_response/3,
		error/3
		]).

%% Listener process
-export([receiver_loop/3]).


-include("pg_msgs.hrl").

-define(REQUIRED_OPTIONS,[database,user,password]).	     

-record(pgsql2,{
			socket,
			listener,  %listener process
			client_pid, %client process...
			parameters,  %parameters given by server after authentication
			backend_id,  %used with the backend_secret to cancel a request
			backend_secret,
			state_data,   %track state-specific data, such as rows in a result set 
			decode_response,  %boolean() wether the driver must decode the response fields or let them intact
			decoders,      %ets map with decoders from know postgres types
			response_format %binary | text . Format that Postgres must use to return data. 
			}). 


-record(equery_r, {
	decode_response,
	cols_description,
	rows
	}).

% Options documentation in pgsql2:connect/1
% @see pgsql2:connect/1
start_link(Options) ->
	case gen_fsm:start_link(?MODULE,{Options,self()},[]) of
		{ok,Pid} ->	receive
						{fsm_started,Pid} -> {ok,Pid}
					after
						5000 -> {error,timeout}
					end;
		X -> X
	end.






%%--------------------gen_fsm callbacks------------------------------------------------------

init({Options,Client}) ->
	check_options(Options) ,
	Database = proplists:get_value(database,Options),
	User = proplists:get_value(user,Options),
	Password = proplists:get_value(password,Options),
	connect(User,Password,Database,Client,Options).
	
connect(User,Password,Database,Client,Options) ->
	{tcp,Host,Port} = proplists:get_value(connection,Options,{tcp,"localhost",5432}),
	case gen_tcp:connect(Host,Port,[{active, false}, binary, {packet, raw}]) of
		{ok,Socket} -> setup_connection(User,Password,Database,Socket,Client,Options);
		Error -> throw(Error)
	end.

setup_connection(User,Password,Database,Socket,Client,Options) ->
	
	StartupMsg = pgsql2_proto_msgs:startup_msg(User,Database),
	gen_tcp:send(Socket,StartupMsg),
	Listener = spawn_link(?MODULE,receiver_loop,[self(),Socket,<<>>]),
	ok = gen_tcp:controlling_process(Socket,Listener),
	ResponseFormat = proplists:get_value(protocol_response_format,Options,binary),
	DecodeResponse = proplists:get_value(decode_response,Options,true),
	Table = ets:new(decoders,[set]),
	{ok,wait_for_auth_request,
		#pgsql2{
		socket=Socket,
		listener=Listener,
		parameters=[],
		state_data={User,Password},%next state will need this for authentication
		decode_response = DecodeResponse,
		decoders=Table,
		client_pid = Client,
		response_format=ResponseFormat},5000}.



handle_event(Event,StateName,StateData) ->
	{stop,{unexpected_event,Event,StateName},StateData}.
	

handle_sync_event(tcp_closed,_From,_StateName,StateData) ->
	{stop,connection_closed,StateData};
	
handle_sync_event(get_parameters,_From,StateName,StateData) ->
	{reply,{ok,StateData#pgsql2.parameters},StateName,StateData};	

handle_sync_event(Event,_From,StateName,StateData) ->
	{stop,{unexpected_event,Event,StateName},StateData}.
	

handle_info(Info,StateName,StateData) ->
	{stop,{unexpected_event,Info,StateName},StateData}.

terminate(_Reason,_StateName,_StateData) ->
	ok.

code_change(_OldVsn, StateName, StateData, _Extra) ->
	{ok,StateName,StateData}.



wait_for_auth_request(#pg_auth_request{auth_method=Method,salt=Salt},_Listener,St) ->
	{User,Password} = St#pgsql2.state_data,
	NewSt = St#pgsql2{state_data=none}, %%Password information won't needed anymore
	case Method of
		%%plain text
		3 -> Msg = pgsql2_proto_msgs:plain_text_password_msg(Password),
			 gen_tcp:send(St#pgsql2.socket,Msg),
			 {reply,ok,wait_for_auth_response,NewSt,5000};
		%%md5 password			
		5 -> Msg = pgsql2_proto_msgs:md5_password_msg(Password,
		       							             User,
		       							             Salt),
			 gen_tcp:send(St#pgsql2.socket,Msg),
			 {reply,ok,wait_for_auth_response,NewSt,5000};		       							             
		N -> {stop,{nyi,{authentication_method,N}},NewSt}
	end.
	

wait_for_auth_response(#pg_auth_request{auth_method=0},_Listener,St) ->
	{reply,ok,wait_for_server_settings,St};
	
wait_for_auth_response(#pg_error{msg=_Error},_Listener,St) ->
	{stop,authentication_error,St}.

	
	
wait_for_server_settings(#pg_error{msg=_Error},_Listener,St) ->
	{stop,server_error,St};

wait_for_server_settings(#pg_parameter_status{name=Key,value=Value},_Listener,St) ->
	{reply,ok,wait_for_server_settings,St#pgsql2{parameters=[{Key,Value}|St#pgsql2.parameters]}};
	
wait_for_server_settings(#pg_backend_key_data{id=ID,secret=Secret},_Listener,St) ->
	{reply,ok,wait_for_server_settings,St#pgsql2{backend_id=ID,backend_secret=Secret}};

wait_for_server_settings(N=#pg_notice_response{},_Listener,St)->
	 io:format("Notice: ~p ~n",[N]),
	 {reply,ok,wait_for_server_settings,St};
	 
wait_for_server_settings(#pg_ready_for_query{},_Listener,St) ->
 	Msg =  pgsql2_proto_msgs:simple_query("SELECT oid, typname FROM pg_type"),
 	gen_tcp:send(St#pgsql2.socket,Msg),
    {reply,ok,wait_for_types_info,St}.
	
wait_for_types_info(#pg_row_description{},_Listener,St) ->
	{reply,ok,wait_for_types_info,St};
wait_for_types_info(#pg_command_complete{},_Listener,St) ->	
	{reply,ok,wait_for_types_info,St};
wait_for_types_info(#pg_data_row{row=Row},_Listener,St) ->
	[Oid,TypeName] = Row,
	case lists:member(TypeName,pgsql2_types:supported_types()) of
		false -> ok;
		true ->  OidNumber = list_to_integer(binary_to_list(Oid)),
% 				 io:format("~p -> ~p ~n",[OidNumber,TypeName]),
				 ets:insert(St#pgsql2.decoders,
					{OidNumber,pgsql2_types:decoder_for(TypeName)})
	end,
	{reply,ok,wait_for_types_info,St};
	
wait_for_types_info(#pg_ready_for_query{status=_Status},_Listener,St)->
	St#pgsql2.client_pid ! {fsm_started,self()},
	{reply,ok,ready_for_query,St};
	
wait_for_types_info(X,_Listener,St) ->	
	io:format("Got: ~p ~n",[X]),
	{reply,ok,wait_for_types_info,St}.
	



ready_for_query({q,Query},Client,St) ->
	Msg = pgsql2_proto_msgs:simple_query(Query),
	ok = gen_tcp:send(St#pgsql2.socket,Msg),
	%{next_state,wait_for_squery_response,St#pgsql2{client_pid=Client,state_data=[]}};
	{next_state,wait_for_equery_response,St#pgsql2{client_pid=Client,
		state_data=#equery_r{decode_response=St#pgsql2.decode_response}}};
	
ready_for_query({q,Query,Params,Options},Client,St) ->
	ResponseFormat = proplists:get_value(protocol_response_format,Options,St#pgsql2.response_format),
	DecodeResponse = proplists:get_value(decode_response,Options,St#pgsql2.decode_response),
	Msg = pgsql2_proto_msgs:extended_query(Query,Params,ResponseFormat),
	ok = gen_tcp:send(St#pgsql2.socket,Msg),
	{next_state,wait_for_equery_response,
		St#pgsql2{client_pid=Client,state_data=#equery_r{decode_response=DecodeResponse}}};
	
ready_for_query({execute_batch,Query,Params},Client,St) ->
	Msg = pgsql2_proto_msgs:execute_batch(Query,Params),
	ok = gen_tcp:send(St#pgsql2.socket,Msg),
	{next_state,wait_for_execute_batch_response,St#pgsql2{client_pid=Client}};
	 
ready_for_query(stop,_Client,StateData)	->
	Msg = pgsql2_proto_msgs:terminate(),
	ok = gen_tcp:send(StateData#pgsql2.socket,Msg),
	StateData#pgsql2.listener ! stop,
	{stop,normal,ok,StateData}.

	


wait_for_equery_response(#pg_bind_complete{},_Listener,St) ->
	 {reply,ok,wait_for_equery_response,St};
wait_for_equery_response(#pg_command_complete{},_Listener,St) ->
	 {reply,ok,wait_for_equery_response,St};
wait_for_equery_response(#pg_parse_complete{},_Listener,St) ->
	 {reply,ok,wait_for_equery_response,St};
	 

wait_for_equery_response(N=#pg_notice_response{},_Listener,St) ->
	 io:format("Notice: ~p ~n",[N]),
	 {reply,ok,wait_for_equery_response,St};
	 
wait_for_equery_response(#pg_error{msg=Error},_Listener,St) ->	 
	{reply,ok,error,St#pgsql2{state_data=Error}};
	
wait_for_equery_response(#pg_ready_for_query{status=_Status},_Listener,St)->
	#equery_r{rows=Rows} = St#pgsql2.state_data,
	gen_fsm:reply(St#pgsql2.client_pid,{ok,Rows}),
	{reply,ok,ready_for_query,St#pgsql2{state_data=none}};
		
wait_for_equery_response(#pg_data_row{row=Row},_Listener,St=#pgsql2{state_data=EqueryData})->
	#equery_r{cols_description = Decoders,
			  decode_response=DecodeResp,
			  rows=Rows} = EqueryData,
	DecodedRow = if 
					DecodeResp -> decode_row(Row,Decoders);
				 	not DecodeResp -> Row
				 end,
	{reply,ok,wait_for_equery_response,
		St#pgsql2{state_data=EqueryData#equery_r{rows=[DecodedRow|Rows]}}};
	
wait_for_equery_response(#pg_row_description{cols=Cols}, _Listener,St) ->
	#pgsql2{decoders=DecodersTable,state_data=StateData} = St,
	#equery_r{decode_response=DecodeResponse} = StateData,
	RowDecoders = if 
		DecodeResponse ->
			 lists:map(fun(#pg_col_description{type=Type,format_code=Format}) -> 
				case ets:lookup(DecodersTable,Type) of
					[] -> {pgsql2_types:default_decoder(),Format};
					[{Type,Decoder}] -> {Decoder,Format}
				end
			end, Cols);
		not DecodeResponse -> none
	end,
	EqueryData = StateData#equery_r{cols_description = RowDecoders,rows=[]},
	{reply,ok,wait_for_equery_response,St#pgsql2{state_data=EqueryData}};

wait_for_equery_response(X,_Listener,St) ->	
	io:format("GOT: ~p",[X]),
	{reply,ok,wait_for_equery_response,St}.


	
wait_for_execute_batch_response(#pg_bind_complete{},_Listener,St) ->	 
	{reply,ok,wait_for_execute_batch_response,St};
	
wait_for_execute_batch_response(#pg_command_complete{},_Listener,St) ->	 
	{reply,ok,wait_for_execute_batch_response,St};

wait_for_execute_batch_response(#pg_parse_complete{},_Listener,St) ->	 
	{reply,ok,wait_for_execute_batch_response,St};
	
wait_for_execute_batch_response(#pg_ready_for_query{status=_Status},_Listener,St) ->
	gen_fsm:reply(St#pgsql2.client_pid,ok),
	{reply,ok,ready_for_query,St#pgsql2{state_data=none}};

wait_for_execute_batch_response(#pg_error{msg=Error},_Listener,St) ->	 
	{reply,ok,error,St#pgsql2{state_data=Error}};
	 
wait_for_execute_batch_response(X,_Listener,St) ->	
	io:format("GOT: ~p",[X]),
	{reply,ok,wait_for_execute_batch_response,St}.
	
	
	 
error(#pg_ready_for_query{status=_Status},_Listener,St=#pgsql2{state_data=Error}) ->
	gen_fsm:reply(St#pgsql2.client_pid,{error,Error}),
	{reply,ok,ready_for_query,St#pgsql2{state_data=none}};
	 
error(_X,_Listener,St) ->
	{reply,ok,error,St}.
	 
	 
%% ------------------Listener process ------------------

receiver_loop(ClientFSM, Socket, Buffer) ->
	inet:setopts(Socket, [{active, once}]),
    receive
		stop ->
	    	gen_tcp:close(Socket);
		{tcp, Socket, Data} -> 
	    	{ok, NewBuffer} = process_buffer(<<Buffer/binary,Data/binary>>,ClientFSM),
	    	receiver_loop(ClientFSM, Socket, NewBuffer);
		{tcp_closed, Socket} ->
	    	gen_fsm:sync_send_all_state_event(ClientFSM, tcp_closed)
    end.
	


%% Given a binary that begins with a proper message header the binary
%% will be processed for each full message it contains, and it will
%% return any trailing incomplete messages.
process_buffer(Bin = <<Code:8/integer, Size:4/integer-unit:8, Rest/binary>>,ClientFSM) ->
    Payload = Size - 4,
    if
	size(Rest) >= Payload ->
	    <<Packet:Payload/binary, Rest1/binary>> = Rest,
	    Message = pgsql2_packet_parser:decode_packet(Code, Packet),
	    gen_fsm:sync_send_event(ClientFSM,Message),
	    process_buffer(Rest1,ClientFSM);
	true ->
	    {ok, Bin}
    end;
process_buffer(Bin,_ClientFSM)  ->
    {ok, Bin}. 
%%SEE: perhaps we can obtain better performance by passing the binary to thr fsm rather
	%%     than the decoded packet.. as the binaries doesn't need to be copied accross process
	%%     boundaries??


	

%% ---------------- Internal funtions ------------------
check_options(Options) ->
	lists:foreach(fun(Required) ->
	                 case proplists:is_defined(Required,Options) of
	                 	true -> ok;
	                 	false -> throw({option_required,Required})
	                 end
	              end,?REQUIRED_OPTIONS).




	




decode_row(Row,Decoders) -> 
	decode_row(Row,Decoders,[]).

decode_row([null|RestCols],[_F|RestDecoders],Accum) ->
	decode_row(RestCols,RestDecoders,[null|Accum]);
	
decode_row([X|RestCols],[{F,Format}|RestDecoders],Accum) ->
	decode_row(RestCols,RestDecoders,[F(Format,X)|Accum]);	

% decode_row([],[_F|RestDecoders],Accum) ->	%%missing columns
%  	decode_row([],RestDecoders,[null|Accum]);
	
decode_row([],[],Accum) ->	
	lists:reverse(Accum).
	


		


% Type: [<<"16">>,<<"bool">>]
% Type: [<<"17">>,<<"bytea">>]
% Type: [<<"18">>,<<"char">>]
% Type: [<<"19">>,<<"name">>]
% Type: [<<"20">>,<<"int8">>]
% Type: [<<"21">>,<<"int2">>]
% Type: [<<"22">>,<<"int2vector">>]
% Type: [<<"23">>,<<"int4">>]
% Type: [<<"24">>,<<"regproc">>]
% Type: [<<"25">>,<<"text">>]
% Type: [<<"26">>,<<"oid">>]
% Type: [<<"27">>,<<"tid">>]
% Type: [<<"28">>,<<"xid">>]
% Type: [<<"29">>,<<"cid">>]
% e: [<<"700">>,<<"float4">>]
% Type: [<<"701">>,<<"float8">>]
% Type: [<<"1043">>,<<"varchar">>]
% Type: [<<"1082">>,<<"date">>]
% Type: [<<"1083">>,<<"time">>]
% Type: [<<"1114">>,<<"timestamp">>]
% 
