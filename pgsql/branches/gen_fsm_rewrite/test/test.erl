-module(test).

-export([test/0]).

-export([pquery2/1,squery2/1,squery/1,pquery2_conversion_off/1,pquery2_text/1]).


-define(R,2000).
-define(Q,"select * from test").

%% Modify this 
-define(DB_USER,"**USER**").
-define(DB_PASS,"**PASS**").
-define(DB_DATABASE,"**DB**").

repeat(_Fun,0) ->
	ok;

repeat(Fun,N) ->
	Fun(),
	repeat(Fun,N-1).





pquery2(Pid2) ->
		 F = fun() -> pgsql2:q(Pid2,?Q,[],[]) end,
		 repeat(F,?R).
    
pquery2_text(Pid2) ->
		 F = fun() -> pgsql2:q(Pid2,?Q,[],[{protocol_response_format,text}]) end,
		 repeat(F,?R).
    
squery2(Pid2) ->
	F = fun() ->  pgsql2:q(Pid2,?Q) end,
	repeat(F,?R).
    
pquery2_conversion_off(Pid2) ->
		 F = fun() -> pgsql2:q(Pid2,?Q,[],[{decode_response,false},{protocol_response_format,text}]) end,
		 repeat(F,?R).
    
  

squery(PidOriginal) ->
 		F = fun() ->pgsql:squery(PidOriginal,?Q) end,
 		repeat(F,?R).
 		
    

test() ->
	io:format("Connecting pgsql2 ~n"),
	{ok,Pid2} = pgsql2:connect(?DB_USER,?DB_PASS,?DB_DATABASE,[]),
	{ok,Pid3} = pgsql2:connect(?DB_USER,?DB_PASS,?DB_DATABASE,[{decode_response,false}]),
	io:format("Connecting pgsql ~n"),
	{ok,PidOriginal} = pgsql:connect("localhost",?DB_DATABASE,?DB_USER,?DB_PASS),
    io:format("Perfoming queries.. ~n"),
    {Time1,ok} = timer:tc(?MODULE,pquery2,[Pid2]),
    {Time2,ok}= timer:tc(?MODULE,pquery2_text,[Pid2]),
    {Time3,ok} = timer:tc(?MODULE,squery2,[Pid2]),
    {Time4,ok} = timer:tc(?MODULE,squery,[PidOriginal]),
    {Time5,ok}= timer:tc(?MODULE,pquery2_conversion_off,[Pid2]),
    {Time6,ok}= timer:tc(?MODULE,squery2,[Pid3]),
    io:format("pgsql2:q/4 Conversion(On) format(binary)-> ~p ~n",[Time1]),
    io:format("pgsql2:q/4 Conversion(On) format(text)-> ~p ~n",[Time2]),
    io:format("pgsql2:q/2 (squery)Conversion(On) format(text)-> ~p ~n",[Time3]),
	io:format("pgsql2:q/2 (squery)Conversion(Off) format(text)-> ~p ~n",[Time6]),
	io:format("pgsql2:q/4 Conversion(Off) format(text)-> ~p ~n",[Time5]),
	io:format("------- ~n"),
	io:format("pgsql:squery/2 -> ~p ~n",[Time4]),
	pgsql:terminate(PidOriginal),
	pgsql2:stop(Pid2),
	ok.
	

