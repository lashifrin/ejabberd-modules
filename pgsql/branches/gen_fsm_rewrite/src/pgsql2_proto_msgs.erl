%%% @author  Pablo Polvorin <pablo.polvorin@process-one.net>
%% %@doc Functions to build frontend(driver)  packets for the postgres protocol
-module(pgsql2_proto_msgs).



-export([startup_msg/2,plain_text_password_msg/1,md5_password_msg/3,simple_query/1,extended_query/3,execute_batch/2]).

%%% Version 3.0 of the protocol.
%%% Supported in postgres from version 7.4
-define(PROTOCOL_MAJOR, 3).
-define(PROTOCOL_MINOR, 0).


startup_msg(UserName,DatabaseName) ->
    Version = <<?PROTOCOL_MAJOR:16/integer, ?PROTOCOL_MINOR:16/integer>>,
    User = make_pair(<<"user">>, UserName),
    Database = make_pair(<<"database">>, DatabaseName),
    StartupPacket = <<Version/binary,
		     User/binary,
		     Database/binary,
		     0>>,
    PacketSize = 4 + size(StartupPacket),
    <<PacketSize:32/integer, StartupPacket/binary>>.
    
    


	
plain_text_password_msg(Password) ->
	Pass = [Password, 0],
	encode($p,list_to_binary(Pass)). 


md5_password_msg(Password,User,Salt) ->
	Digest = hex(md5([Password, User])),
    Encrypt = hex(md5([Digest, Salt])),
    Pass = ["md5", Encrypt, 0],
    encode($p,list_to_binary(Pass)).



simple_query(Query) ->
	  encode($Q, string(Query)).




extended_query(Query,Params,ResponseFormat) ->
    ParseP =    parse("", Query, []),
    BindP =     bind("", "", Params, [ResponseFormat]), %%TODO why as list?
    DescribeP = describe(portal, ""),
    ExecuteP =  execute("", 0),
    SyncP =     sync([]),
    [ParseP,BindP,DescribeP,ExecuteP,SyncP].

execute_batch(Query,Params) ->
    ParseP =    parse("", Query, []),
    
    BindsP = lists:map(fun(IterParams) ->
			BindP =     bind("", "", IterParams, [binary]),
			ExecuteP =  execute("", 0),
			[BindP,ExecuteP]
    end,Params),
    % 			DescribeP = describe(portal, ""),    
    SyncP = sync([]),
    [ParseP,BindsP,SyncP].





parse(Name, Query, _Oids) ->
    StringName = string(Name),
    StringQuery = string(Query),
    encode($P, <<StringName/binary, StringQuery/binary, 0:16/integer>>).

bind(NamePortal, NamePrepared,Parameters, ResultFormats) ->
    PortalP = string(NamePortal),
    PreparedP = string(NamePrepared),

    ParamFormatsList = lists:map(
			 fun (Bin) when is_binary(Bin) -> <<1:16/integer>>;
			     (_Text) -> <<0:16/integer>> end,
			 Parameters),
    ParamFormatsP = list_to_binary(ParamFormatsList),

    NParameters = length(Parameters),
    ParametersList = lists:map(
		       fun (null) ->
			       Minus = -1,
			       <<Minus:32/integer>>;
			   (Bin) when is_binary(Bin) ->
			       Size = size(Bin),
			       <<Size:32/integer, Bin/binary>>;
			   (Integer) when is_integer(Integer) ->
			       List = integer_to_list(Integer),
			       Bin = list_to_binary(List), %%TODO: this isn't neccesary?
			       Size = size(Bin),
			       <<Size:32/integer, Bin/binary>>;
			   (Text) ->
			       Bin = list_to_binary(Text),
			       Size = size(Bin),
			       <<Size:32/integer, Bin/binary>>
		       end,
		       Parameters),
    ParametersP = list_to_binary(ParametersList),

    NResultFormats = length(ResultFormats),
    ResultFormatsList = lists:map(
			  fun (binary) -> <<1:16/integer>>;
			      (text) ->	  <<0:16/integer>> end,
			  ResultFormats),
    ResultFormatsP = list_to_binary(ResultFormatsList),

    encode($B, <<PortalP/binary, PreparedP/binary,
		NParameters:16/integer, ParamFormatsP/binary,
		NParameters:16/integer, ParametersP/binary,
		NResultFormats:16/integer, ResultFormatsP/binary>>).
		
describe(portal, Name) ->
    NameP = string(Name),
    encode($D, <<$P:8/integer, NameP/binary>>);

describe(prepared_statement,Name) ->
	 NameP = string(Name),
	 encode($D, <<$S:8/integer, NameP/binary>>).
	 
execute(Portal, Limit) ->
    String = string(Portal),
    encode($E, <<String/binary, Limit:32/integer>>).
    
sync(_) ->
    encode($S, <<>>).



%% Add header to a message.
encode(Code, Packet) ->
    Len = size(Packet) + 4,
    <<Code:8/integer, Len:4/integer-unit:8, Packet/binary>>.






%% -----------utility functions -----------------------
%%% Two zero terminated strings.
%% Key must be binary() value could be binary() | string()
make_pair(Key, Value) when list(Value) ->
    make_pair(Key, list_to_binary(Value));
make_pair(Key, Value) when binary(Key), binary(Value) ->
    <<Key/binary, 0/integer, 
     Value/binary, 0/integer>>.
     
     
hex(B) when binary(B) ->
    hexlist(binary_to_list(B), []).

hexlist([], Acc) ->
    lists:reverse(Acc);
hexlist([N|Rest], Acc) ->
    HighNibble = (N band 16#f0) bsr 4,
    LowNibble = (N band 16#0f),
    hexlist(Rest, [hexdigit(LowNibble), hexdigit(HighNibble)|Acc]).

hexdigit(0) -> $0;
hexdigit(1) -> $1;
hexdigit(2) -> $2;
hexdigit(3) -> $3;
hexdigit(4) -> $4;
hexdigit(5) -> $5;
hexdigit(6) -> $6;
hexdigit(7) -> $7;
hexdigit(8) -> $8;
hexdigit(9) -> $9;
hexdigit(10) -> $a;
hexdigit(11) -> $b;
hexdigit(12) -> $c;
hexdigit(13) -> $d;
hexdigit(14) -> $e;
hexdigit(15) -> $f.

md5(X) -> erlang:md5(X).


string(String) when list(String) ->
    Bin = list_to_binary(String),
    <<Bin/binary, 0/integer>>;
string(Bin) when binary(Bin) ->
    <<Bin/binary, 0/integer>>.