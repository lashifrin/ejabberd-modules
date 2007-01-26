%%% File    : xmpp_component.erl
%%% Author  : Mickael Remond <mremond@process-one.net>
%%% Description : This is a worker supervised in charge of connecting the
%%%               Jabber gateway to the Jabber it is acting as a component.
%%% This FSM is for now very simple as it has only one state.               
%%% Created :  3 May 2006 by Mickael Remond <mremond@process-one.net>
%%%-------------------------------------------------------------------
-module(xmpp_component).

-behaviour(gen_fsm).

-export([start_link/5,
	 send_to_server/1]).

%% States:
-export([wait_open_stream/2,
         wait_handshake/2,
   	 connected/2]).

%% TODO: Manage debug mode

%% FSM:
-export([init/1,
         handle_event/3,
         handle_sync_event/4,
         code_change/4,
         handle_info/3,
         terminate/3]).

%% Internal:
-export([receiver/2]).

-record(state, {name, secret, host, port, socket, module, mod_pid}).

-define(CHILDID, component).

%-define(DBGFSM, true).
-ifdef(DBGFSM).
-define(FSMOPTS, [{debug, [trace]}]).
-else.
-define(FSMOPTS, []).
-endif.

%% Start xmmp_component manager
start_link(ComponentName, Server, Port, Secret, Module) ->
    gen_fsm:start_link({local, ?MODULE},
		       ?MODULE,
		       [ComponentName, Server, Port, Secret, Module],
		       [?FSMOPTS]).

%% Send the message via the server we are connected to
send_to_server(XMLString) ->
    gen_fsm:send_event(?MODULE, {send, XMLString}).

init([ComponentName, Server, Port, Secret, Module]) ->
    Socket = connect(ComponentName, Server, Port),
    Pid = start_xml_parser(Socket),
    gen_tcp:controlling_process(Socket, Pid),
    ok = stream_open(Socket, ComponentName, Server),
    {ok, wait_open_stream, #state{name=ComponentName,
				  secret=Secret,
				  host=Server,
				  port=Port,
				  socket=Socket,
				  module=Module}}.

%%--------------------------------------------------------------------
%% Function: 
%% state_name(Event, State) -> {next_state, NextStateName, NextState}|
%%                             {next_state, NextStateName, 
%%                                NextState, Timeout} |
%%                             {stop, Reason, NewState}
%% Description:There should be one instance of this function for each possible
%% state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_event/2, the instance of this function with the same name as
%% the current state name StateName is called to handle the event. It is also 
%% called if a timeout occurs. 
%%--------------------------------------------------------------------
wait_open_stream({xmlstreamstart,"stream:stream", Attrs}, State) ->
    StreamID = get_stream_id(Attrs),
    handshake(State#state.socket, StreamID, State#state.secret),
    {next_state, wait_handshake, State};
wait_open_stream(Event, State) ->
    io:format("EV: ~p~n", [Event]),
    {next_state, wait_open_stream, State}.

wait_handshake({xmlstreamelement,{xmlelement,"handshake",_,[]}}, State) ->
    %% Get module PID
    ComponentName = State#state.name,
    Module = State#state.module,
    
    %ModuleSpec = {?CHILDID,
    %		  {Module, start_link, [server_host(ComponentName),
    %					[{host,ComponentName}]]},
    %		  permanent,5000,worker,[Module]},
    %{ok, ModulePid} = supervisor:start_child(ejabberd_sup, ModuleSpec),
    {ok, ModulePid} = Module:start(server_host(ComponentName),[{host,ComponentName}]),
    {next_state, connected, State#state{mod_pid=ModulePid}};
wait_handshake(Event, State) ->
    io:format("EV: ~p~n",[Event]),
    {next_state, wait_handshake, State}.

connected({send, XMLString}, State) ->
    gen_tcp:send(State#state.socket, XMLString),
    {next_state, connected, State};
connected({xmlstreamelement, Packet}, State) ->
    {xmlelement, _Name, Attrs, _Els} = Packet,
    To   = xml:get_attr_s("to", Attrs),
    From = xml:get_attr_s("from", Attrs),

    State#state.mod_pid ! {route, 
			   jlib:string_to_jid(From),
			   jlib:string_to_jid(To),
			   Packet},

    {next_state, connected, State};
connected(Event, State) ->
    io:format("EV: ~p~n",[Event]),
    {next_state, connected, State}.

%%--------------------------------------------------------------------
%% Function: 
%% handle_event(Event, StateName, State) -> {next_state, NextStateName, 
%%						  NextState} |
%%                                          {next_state, NextStateName, 
%%					          NextState, Timeout} |
%%                                          {stop, Reason, NewState}
%% Description: Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_all_state_event/2, this function is called to handle
%% the event.
%%--------------------------------------------------------------------
handle_event(_Event, StateName, State) ->
    {next_state, StateName, State}.

%%--------------------------------------------------------------------
%% Function: 
%% handle_sync_event(Event, From, StateName, 
%%                   State) -> {next_state, NextStateName, NextState} |
%%                             {next_state, NextStateName, NextState, 
%%                              Timeout} |
%%                             {reply, Reply, NextStateName, NextState}|
%%                             {reply, Reply, NextStateName, NextState, 
%%                              Timeout} |
%%                             {stop, Reason, NewState} |
%%                             {stop, Reason, Reply, NewState}
%% Description: Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_all_state_event/2,3, this function is called to handle
%% the event.
%%--------------------------------------------------------------------
handle_sync_event(_Event, _From, StateName, State) ->
    Reply = ok,
    {reply, Reply, StateName, State}.

%%--------------------------------------------------------------------
%% Function: 
%% handle_info(Info,StateName,State)-> {next_state, NextStateName, NextState}|
%%                                     {next_state, NextStateName, NextState, 
%%                                       Timeout} |
%%                                     {stop, Reason, NewState}
%% Description: This function is called by a gen_fsm when it receives any
%% other message than a synchronous or asynchronous event
%% (or a system message).
%%--------------------------------------------------------------------
handle_info(_Info, StateName, State) ->
    {next_state, StateName, State}.

%%--------------------------------------------------------------------
%% Function: terminate(Reason, StateName, State) -> void()
%% Description:This function is called by a gen_fsm when it is about
%% to terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_fsm terminates with
%% Reason. The return value is ignored.
%%--------------------------------------------------------------------
terminate(_Reason, _StateName, _State) ->
    ok.

%%--------------------------------------------------------------------
%% Function:
%% code_change(OldVsn, StateName, State, Extra) -> {ok, StateName, NewState}
%% Description: Convert process state when code is changed
%%--------------------------------------------------------------------
code_change(_OldVsn, StateName, State, _Extra) ->
    {ok, StateName, State}.

%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------

%% Connect to the Jabber / XMPP server using the component protocol.
connect(_ComponentName, Server, Port) ->
    Socket = case gen_tcp:connect(Server, Port, [binary,{active, false},{packet, 0}], 10000) of
		 {ok, Sock}      -> Sock;
		 {error, Reason} -> io:format("Connection error: [~p]~n", [Reason]),
				    exit(Reason)
	     end,
    Socket.

stream_open(Socket, ComponentName, _Server) ->
    Packet =["<stream:stream xmlns='jabber:component:accept'"
	     " xmlns:stream='http://etherx.jabber.org/streams'"
	     " to='", ComponentName, "'>"],
    gen_tcp:send(Socket, Packet).

handshake(Socket, StreamID, Secret) ->
    Handshake = sha:sha(StreamID ++ Secret),
    Packet =["<handshake>", Handshake, "</handshake>"],
    gen_tcp:send(Socket, Packet).

%% Extract the stream id from the 
get_stream_id(StreamXMLAttrs) ->
    case lists:keysearch("id", 1, StreamXMLAttrs) of
	{value,{"id",StreamID}} -> StreamID;
	false -> ""
    end.

%% TODO: Turn this into a worker gen_server
%% Place it under a the same xmpp_component_sup
%% When one of them crash, the supervisor restarts the two workers process
%% -----
%% Parsing and reception process
start_xml_parser(Socket) ->
    ok = erl_ddll:load_driver(epeios_config:lib_path(), expat_erl),
    XMLStreamState = xml_stream:new(self()),
    spawn_link(?MODULE, receiver, [Socket, XMLStreamState]).

receiver(Socket, XMLStreamState) ->
    process_flag(trap_exit, true),
    receiver_loop(Socket, XMLStreamState).
receiver_loop(Socket, XMLStreamState) ->
    case gen_tcp:recv(Socket, 0) of
        {ok, Data} ->
            NewXMLStreamState = xml_stream:parse(XMLStreamState, Data),
            receiver_loop(Socket, NewXMLStreamState);
        {error, Reason} ->
            io:format("Receiver loop: error: ~p~n",[Reason]),
            xml_stream:close(XMLStreamState), 
            exit({error, Reason});
        %% Trap exit signal:
        Other ->
            io:format("Receiver loop: received: ~p~n",[Other]),
	    xml_stream:close(XMLStreamState),
            exit({error, Other})
    end.


%% Helper function
%% Return the server hostname, given the component name
server_host(ComponentName) ->						
    %% The server hostname is the last part of the component name
    case string:chr(ComponentName, $.) of
	0 -> exit("invalid component name~n");
	N -> string:substr(ComponentName, N+1)
    end.
