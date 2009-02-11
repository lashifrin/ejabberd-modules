%% This module is a stripped downed version of 
-module(ejabberd_router).

-export([register_route/1,
	 unregister_route/1,
	 route/3]).

register_route(_Host) ->
    {atomic, ok}.
unregister_route(_Host) ->
    {atomic, ok}.

route(From, To, Packet) ->
    %% Generate XML string from packet
    Packet2 = jlib:replace_from_to(From, To, Packet),
    PacketString = xml:element_to_string(Packet2),
    xmpp_component:send_to_server(PacketString).
