%% Connection pooling test
%% TODO: MAKE THIS A REAL TEST, using some test framework
%% TODO: test transaction crash

-module(conn_pool_test).


-export([test/0]).

-export([loop/3]).


-define(Q,"select * from test").

%% Modify this 
-define(DB_USER,"imtrendsbot").
-define(DB_PASS,"imtrends").
-define(DB_DATABASE,"imtrends").

-define(N_PROCESS,20).
-define(N_QUERIES_PER_PROCESS,50).


tx(Conn) ->
  {ok,_Rows} = pgsql2:q(Conn,?Q),
  ok.
  
  
test() ->
  {ok,Pool} = pgsql2_pool:start_link(?DB_USER,?DB_PASS,?DB_DATABASE,[],5),
  
  lists:foreach(fun(_) -> 
                spawn(?MODULE,loop,[?N_QUERIES_PER_PROCESS,Pool,self()]) 
              end, lists:duplicate(?N_PROCESS,1)),
  wait_for_responses(?N_PROCESS).
  
  
wait_for_responses(0) ->
  io:format("Test Ok ~n");
  
wait_for_responses(N) ->
  receive
    ok -> wait_for_responses(N-1)
  after
    5000 -> io:format("Test Fail ~n")
  end.
  
  
  
loop(0,_Pool,Parent) -> Parent ! ok;

loop(N,Pool,Parent) -> 
      {ok,ok} = pgsql2_pool:apply_in_tx(Pool,fun tx/1,[]),
      loop(N-1,Pool,Parent).
            