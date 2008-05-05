%%% @author  Pablo Polvorin <pablo.polvorin@process-one.net>
%%% @doc  PostgreSQL Connection Pool
%%%       Attempt to do connection pooling for postgres.
%%%       Basic implementation, almost no error handling
%%%       Connections are created at pool start-time, not
%%%       on a on-demand basis.
%%%       If a transaction fails, the connection in witch 
%%%       the tx executed is closed, and a new connection is open.
%%%       The pool should link to the connection processess, so
%%%       if a connection crash for some reason, the pool could
%%%       see it and create another.

-module(pgsql2_pool).

%%gen_server callbacks
-export([init/1,handle_call/3,handle_cast/2,handle_info/2,terminate/2,code_change/3]).


%% API
-export([start_link/6,apply_in_tx/3]).

-record(pool_state, {
            pool,
            size,
            pending,
            db_info}).


-define(TX_TIMEOUT,5 * 1000). %5 seg

%% @doc Execute a transaction in some connection of the pool. 
%% @see pgsql2:apply_in_tx/3
apply_in_tx(Pool,Fun,Args) ->
  case gen_server:call(Pool,get_connection) of
      {ok,Connection} -> apply_in_tx2(Pool,Connection,Fun,Args);
      {error,X} -> {error,X}
  end.
  
apply_in_tx2(Pool,Connection,Fun,Args) ->
  Client = self(),
  
  TransactionPid = spawn(fun() ->
        try pgsql2:apply_in_tx(Connection,Fun,Args) of
            R -> Client ! {tx_ok,self(),R}
        catch
            throw:{tx_error,Type,Error} -> Client ! {tx_error,self(),{Type,Error}}
        end
  end),
  receive
      {tx_ok,TransactionPid,Result} -> gen_server:cast(Pool,{tx_ok,Connection}),
                                       {ok, Result};
                                       
      {tx_error,TransactionPid,Error} -> gen_server:cast(Pool,{tx_error,Connection,Error}),
                                         {error,Error}
  after
      ?TX_TIMEOUT -> exit(TransactionPid,transaction_timeout),
                     gen_server:cast(Pool,{tx_error,Connection,transaction_timeout}),
                     {error,timeout}
  end.
  
  
%% @doc Start a connection pool      
%%      User,Password,Db and ConnOpts haven the same meaning than in pgsql2:connect/4
%%      PoolSize is the number of connection that this pool will utilize.
start_link(PoolName,User,Password,Db,ConnOpts,PoolSize) ->
  gen_server:start_link({local,PoolName},?MODULE,{User,Password,Db,ConnOpts,PoolSize},[]).
  
  
  
  
init({User,Password,Db,ConnOpts,PoolSize}) ->
    PoolList = lists:map(fun(_) -> make_connection(User,Password,Db,ConnOpts) end, lists:duplicate(PoolSize,1) ),
    Pool = queue:from_list(PoolList),
    {ok,#pool_state{pool=Pool,size=PoolSize,db_info={User,Password,Db,ConnOpts},pending=queue:new()}}.
    
    
handle_call(get_connection,From,State=#pool_state{pool=Pool,pending=Pending}) ->
  case queue:out(Pool) of
     {{value, Item}, Q2} -> {reply,{ok,Item},State#pool_state{pool=Q2}};
     {empty, Pool} -> {noreply,State#pool_state{pending=queue:in(From,Pending)}}
  end.
  
  
handle_cast({tx_ok,Connection},State) ->
  %%TODO: see the state of the connection, make sure the transaction state is correct
  return_connection(Connection,State);
  
handle_cast({tx_error,Connection,_Error},State=#pool_state{db_info=DbInfo}) ->
  ok = pgsql2:stop(Connection),
  {User,Password,Db,Opts} = DbInfo,
  return_connection(make_connection(User,Password,Db,Opts),State).
  
handle_info(Info,_State) ->
  io:format("PGSQL2 POOL> Info: ~p", [Info]).
  
terminate(_Reason,_State) ->
  ok.
  
  
code_change(_Old,State,_Extra) ->
  {ok,State}.
  
  
  
return_connection(Connection,State=#pool_state{pool=Pool,pending=Pending}) ->
  case queue:out(Pending) of
     {{value, Item}, Q2} -> gen_server:reply(Item,{ok,Connection}),
                            {noreply,State#pool_state{pending=Q2}};
     {empty, Pending} -> {noreply,State#pool_state{pool=queue:in(Connection,Pool)}}
  end.
    
  
  
make_connection(User,Password,Db,ConnOpts) ->
  {ok,Pid} = pgsql2:connect(User,Password,Db,ConnOpts),
  Pid.
  
  
  
  
    