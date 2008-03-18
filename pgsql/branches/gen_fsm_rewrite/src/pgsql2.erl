%%% @author  Pablo Polvorin <pablo.polvorin@process-one.net>
%%% @doc  PostgresQL interface
%%% This is a rewrite of the pgsql driver, main differences:
%%%    * Uses binaries rather than lists
%%%    * Protocol code implemented using gen_fsm 
%%%    * Options for decoding values
%%%    * Support for for batch insert/updates 

-module(pgsql2).


% @doc This interface isn't backwards compatible with pgsql. 
%      By default, fields returned by the server are converted to
%      appropriate erlang values, if an appropriate type converted is defined 
%      (float -> float, date -> calendar:date(), timestamp -> calendar:datetime(),.. )
%      See options in connect/4.
%
%       
%
%

-export([connect/4,stop/1,q/2,q/3,q/4,execute/3,execute_many/3,get_parameters/1,apply_in_tx/3]).	


% @spec connect(User,Password,Database,[Option]) -> {ok,Pid} 
% @type Option =  {connection, Connection} |  {protocol_response_format,RespFormat} | 
% 				  {type_decoders,[Module]} | {decode_response,boolean()}
% @type Connection =  {tcp,Host, Port}
% @type RespFormat = binary | text
% @doc Start a pgsql2 driver process, witch maps 1:1 to a database connection.
%      Defaults: {connection,{tcp,"localhost",5432}},{protocol_response_format,binary},{type_decoders,[]}
%                {decode_response,true} 
%
%	   decode_response whether the driver should attempt to decode return values or not. Can be overridde 
%      using query options
%
%      type_decoders  let the user specify new decoders, TODO: NOT YET IMPLEMENTED!
%  
%	   protocol_response_format is the format in witch the Postgres server will return data to the driver.
%      This shouldn't affect the way in witch data is returned from the driver when decode_response is 
%      set to true, as the data decoders should take care of decoding the response into the appropriate 
%      erlang value (note that  for types that doesn't have a decoder, the data is returned to the client as-is, 
%      so the underling format would be visible). The format can be override using query options
%      Note that queries using q/2 aren't affected by this setting, and the response from postgres is always
%      in text format. 
%      Currently, the driver only sends data to the server in text format.
connect(User,Password,Database,Options) ->
	Opts = [{user,User},{password,Password},{database,Database}|Options],
	pgsql2_proto:start_link(Opts).
	
	
stop(Pid) ->
	gen_fsm:sync_send_all_state_event(Pid,stop).

% @spec q(Pid,Query) -> {ok,[Row]} | {error,Reason}
% @type Query = iolist()
% @type Row = list()
% @doc Execute the given Query. The query must not have
%      any placeholder.
%      This function is intended to be used for 
% 	   select-like queries. For insert/updates use execute/3 
%      or execute_many/3.
%      Note that the safest way to build queries containing 
%      parameters is to use q/4
% @see q/4
% @see execute/3
% @see execute_many/3
q(Pid,Query) ->
	gen_fsm:sync_send_event(Pid,{q,Query}).

% @doc Same as q(Pid,Query,Params,[])
% @see q/4
q(Pid,Query,Params) ->
	q(Pid,Query,Params,[]).

% @spec q(Pid,Query,Params,Options) -> {ok,[Row]} | {error,Reason}
% @type Query = iolist()
% @type Params = list()
% @type Options = [Option]
% @type Option = {response_format,Format} | {decode_response,boolean()} 
% @type Format = binary | text
% @type Row = list()
% @doc Execute the given Query. The query could have 
%      placeholders, denoted by $1..$N. The parameters
%      list (could be empty) must have the same number of
%      elements as the number of placeholders in in the 
%      query string.
%      This function is intended to be used for 
% 	   select-like queries. For insert/updates use execute/3 
%      or execute_many/3.
q(Pid,Query,Params,Options) ->
	gen_fsm:sync_send_event(Pid,{q,Query,Params,Options}).


% @spec q(Pid,Query,MultiParams) -> ok | {error,Reason}
% @type Query = iolist()
% @type MultiParams = [Params]
% @type Params = list()
% @doc Prepare a database operation and then
%      execute it against all parameter lists
%      found in the list MultiParams.
%      For batch insert/updates this function
%      should be faster than performing successive
%      calls to execute/3, as the command has to
%      be parsed only once.
execute_many(Pid,Query,Params) ->
	gen_fsm:sync_send_event(Pid,{execute_batch,Query,Params}).


% @spec q(Pid,Query,Params) -> ok | {error,Reason}
% @type Query = iolist()
% @type Params = list()
% @doc Execute a database operation.
%      For batch insert/updates use execute_many/3.
%      For select-like queries use any of q/2,q/3,q/4
%      instead. 
execute(_Pid,_Query,_Params) ->
	%gen_fsm:sync_send_event(Pid,{execute,Query,Params}).
	{error,"Not implemented yet, use execute_many instead"}.


%% @doc Apply the given function in a transactional context 
%%      whithin this connection.
%%      The transaction will be commited if the function 
%%      returns normally, and a rollback is done if the function
%%      throws any exception.
%%      The Function is called with the connection as the first 
%%      argument with the rest of the arguments following.
%%      apply_in_tx(Connection,F,[a,b]) would result in
%%      apply(F,[Connection,a,b])
%%
%%      IMPORTANT!: this implementation isn't safe to be used
%%                  from multiple client process. 
%%TODO: See status field in ready_for_query, to be sure
%% that the transaction is going ok
apply_in_tx(Pid,Fun,Args) ->
	gen_fsm:sync_send_event(Pid,{q,"BEGIN"}),
	try 
		R = apply(Fun,[Pid|Args]),
		gen_fsm:sync_send_event(Pid,{q,"COMMIT"}),
		R
	catch
		Type:Error -> gen_fsm:sync_send_event(Pid,{q,"ROLLBACK"}),
					  throw({tx_error,Type,Error})
	end.
		
 
% @spec get_parameters(Pid) -> {ok,[Parameter]}
% @type Parameter = {Key,Value}
% @doc return the parameters of the server, given 
%      after successfull authentication
%
get_parameters(Pid) ->
	gen_fsm:sync_send_all_state_event(Pid,get_parameters).

