%%% @author  Pablo Polvorin <pablo.polvorin@process-one.net>
%%% @doc Functions to parse backend(db)  packets for the postgres protocol

-module(pgsql2_packet_parser).



-export([decode_packet/2]).

-include("pg_msgs.hrl").

%%% PostgreSQL protocol message codes
-define(PG_BACKEND_KEY_DATA, $K).
-define(PG_PARAMETER_STATUS, $S).
-define(PG_ERROR_MESSAGE, $E).
-define(PG_NOTICE_RESPONSE, $N).
-define(PG_EMPTY_RESPONSE, $I).
-define(PG_ROW_DESCRIPTION, $T).
-define(PG_DATA_ROW, $D).
-define(PG_READY_FOR_QUERY, $Z).
-define(PG_AUTHENTICATE, $R).
-define(PG_BIND, $B).
-define(PG_PARSE, $P).
-define(PG_COMMAND_COMPLETE, $C).
-define(PG_PARSE_COMPLETE, $1).
-define(PG_BIND_COMPLETE, $2).
-define(PG_CLOSE_COMPLETE, $3).
-define(PG_PORTAL_SUSPENDED, $s).
-define(PG_NO_DATA, $n).
%% With a message type Code and the payload Packet apropriate
%% decoding procedure can proceed.
decode_packet(?PG_AUTHENTICATE, Packet) ->
	<<AuthMethod:32/integer, Salt/binary>> = Packet,
    #pg_auth_request{auth_method=AuthMethod,salt=Salt};
    
decode_packet(?PG_ERROR_MESSAGE, Packet) ->	
    Message = errordesc(Packet),
	#pg_error{msg=Message};
	
decode_packet(?PG_PARAMETER_STATUS,Packet) ->
	{Key, Value} = split_pair(Packet),
	#pg_parameter_status{name=Key,value=Value};
	    	
decode_packet(?PG_BACKEND_KEY_DATA,Packet) ->
	 <<Pid:32/integer, Secret:32/integer>> = Packet,
	  #pg_backend_key_data{id=Pid,secret=Secret};
	    
decode_packet(?PG_NOTICE_RESPONSE,Packet) ->
	   #pg_notice_response {notice=notice_response(Packet)};
	    
decode_packet(?PG_READY_FOR_QUERY,Packet) ->	    
	 Status = case Packet of
		<<$I:8/integer>> -> idle;
		<<$T:8/integer>> -> transaction;
		<<$E:8/integer>> -> failed_transaction
	 	end,
	 #pg_ready_for_query{status=Status};


decode_packet(?PG_DATA_ROW,<<NumberCol:16/integer, RowData/binary>>) ->
	    ColData = datacoldescs(NumberCol, RowData, []),
	 	#pg_data_row{row=ColData};
		 
decode_packet(?PG_ROW_DESCRIPTION,<<_Columns:16/integer, ColDescs/binary>>) ->
	 Cols = coldescs(ColDescs, []),
	 #pg_row_description{cols=Cols};

%%TODO: any parameters?
decode_packet(?PG_COMMAND_COMPLETE,_Packet) ->
	#pg_command_complete{};

decode_packet(?PG_EMPTY_RESPONSE,_Packet) ->
	 #pg_empty_response{};
	 	 
	 	 
decode_packet(?PG_PARSE_COMPLETE,_Packet) ->
	#pg_parse_complete{};
		
decode_packet(?PG_BIND_COMPLETE,_Packet) ->
	#pg_bind_complete{};
	 	 
decode_packet(X,_Packet) ->
	throw({unknown_msg_code,X}).
	
	
	
errordesc(Bin) ->
    errordesc(Bin, []).

errordesc(<<0/integer, _Rest/binary>>, Lines) ->
    lists:reverse(Lines);
errordesc(<<Code/integer, Rest/binary>>, Lines) ->
    {String, Count} = to_string(Rest),
    <<_:Count/binary, 0, Rest1/binary>> = Rest,
    Msg = case Code of 
	      $S ->
		  {severity, list_to_atom(String)};
	      $C ->
		  {code, String};
	      $M ->
		  {message, String};
	      $D ->
		  {detail, String};
	      $H ->
		  {hint, String};
	      $P ->
		  {position, list_to_integer(String)};
	      $p ->
		  {internal_position, list_to_integer(String)};
	      $W ->
		  {where, String};
	      $F ->
		  {file, String};
	      $L ->
		  {line, list_to_integer(String)};
	      $R ->
		  {routine, String};
	      Unknown ->
		  {Unknown, String}
	  end,
    errordesc(Rest1, [Msg|Lines]).

to_string(Bin) when binary(Bin) ->    
    {Count, _} = count_string(Bin, 0),
    <<String:Count/binary, _/binary>> = Bin,
    {binary_to_list(String), Count}.
    


count_string(<<>>, N) ->
    {N, <<>>};
count_string(<<0/integer, Rest/binary>>, N) ->
    {N, Rest};
count_string(<<_C/integer, Rest/binary>>, N) ->
    count_string(Rest, N+1).

split_pair(Bin)  ->
    {Key,Rest} = binary_split(0,Bin),
    {Value,_Rest2} = binary_split(0,Rest),
    {Key,Value}.


coldescs(<<>>, Descs) ->
    lists:reverse(Descs);
    
coldescs(Bin, Descs) ->
	{Name,Bin2} = binary_split(0,Bin), %string name
    <<TableOID:32/integer,
     ColumnNumber:16/integer,
     TypeId:32/integer,
     TypeSize:16/integer-signed,
     TypeMod:32/integer-signed,
     FormatCode:16/integer,
     Rest/binary>> = Bin2,
     Format = case FormatCode of 
		 0 -> text; 
		 1 -> binary 
	     end,
 	Desc = #pg_col_description{name =Name,
								table=TableOID,
								col_number=ColumnNumber,
								type=TypeId,
								size=TypeSize,
								type_modifier=TypeMod,
								format_code=Format},
    coldescs(Rest, [Desc|Descs]).



datacoldescs(N, 
	     <<-1:32/integer-signed, Rest/binary>>, 
	     Descs) ->
    datacoldescs(N-1, Rest, [null|Descs]);

datacoldescs(N, 
	     <<Len:32/integer, Data:Len/binary, Rest/binary>>, 
	     Descs) when N > 0 ->
    datacoldescs(N-1, Rest, [Data|Descs]);

datacoldescs(0,<<>>, Descs) ->
    lists:reverse(Descs).



notice_response(Packet)->
	notice_response(Packet,[]).
	
notice_response(<<0>>,Acc)  -> lists:reverse(Acc);
notice_response(<<FieldType:8/integer,Rest/binary>>,Acc) ->
	{Field,Rest2} = binary_split(0,Rest),
	notice_response(Rest2,[{FieldType,Field}|Acc]).





binary_split(ByteValue,Bin) ->
	%binary_split(ByteValue,Bin,[]). 
	binary_split(ByteValue,Bin,0,byte_size(Bin)).
	%%TODO: see the use if binaries as accumulators
	%%TODO: see to use a counter, and match agains <<Passed:Count,Value,Rest/binary>>
	%%      and incremenet counter (like an array, the benefict is that when we find the
    %%			                   one find the value, whe already had the binnary splited)
	
	
binary_split(ByteValue,Bin,Cursor,MaxSize) when Cursor < MaxSize ->
	case Bin of
		<<Head:Cursor/binary,ByteValue,Tail/binary>> ->{Head,Tail};
		_ -> binary_split(ByteValue,Bin,Cursor+1,MaxSize)
	end;
	
binary_split(_ByteValue,Bin,MaxSize,MaxSize) ->
	{Bin,<<>>}.
	
% binary_split(ByteValue,<<ByteValue,Rest/binary>>,Acum) ->
% 	{list_to_binary(lists:reverse(Acum)),Rest};
% 	
% binary_split(ByteValue,<<X,Rest/binary>>,Acum) ->
% 	binary_split(ByteValue,Rest,[X|Acum]).
% 	
% 
