%%% @author  Pablo Polvorin <pablo.polvorin@process-one.net>
%%@doc Default decoders

-module(pgsql2_types).

-export([supported_types/0,decoder_for/1,default_decoder/0]).

% types_encoders:	
% 	string,
% 	integer,
% 	float,
% 	boolean,
% 	date,
% 	datetime,
% 	timestamp


supported_types() ->
	[<<"bool">>,
	<<"int8">>,
	<<"int4">>,
	<<"int2">>,
	<<"float8">>,
	<<"float4">>,
	<<"varchar">>,
	<<"bpchar">>,
	<<"date">>,
	<<"timestamp">>].


%% @doc Return a decoder function for the specified type.
%% @spec decoder_for(Type) -> Decoder()
%% @type Type = binary()
%% @type Decoder = fun (Format,EncodedValue) -> Value
%% @type Format == text|binary
%% @type EncodedValue = binary()
%% @type Value = any()	
decoder_for(<<"bool">>) -> fun decode_bool/2;
decoder_for(T) when T == <<"int8">>;
					T == <<"int4">>;
					T == <<"int2">> -> fun decode_int/2;
	
decoder_for(T) when T == <<"float4">>; 
					T == <<"float8">> ->fun decode_float/2;
						   

decoder_for(<<"date">>) -> fun decode_date/2;

decoder_for(<<"timestamp">>) -> fun decode_timestamp/2;

decoder_for(T) when T == <<"varchar">>;
					T ==  <<"bpchar">> ->fun raw_decoder/2;


	

decoder_for(_T) -> 
	default_decoder().
	
	

		

decode_bool(binary,<<0>>) ->
	false;
	
decode_bool(binary,<<1>>) ->
	true;

decode_bool(text,<<$f>>) ->
	false;
	
decode_bool(text,<<$t>>) ->
	true.


decode_int(binary,Bin) -> 
	Size = bit_size(Bin), %%TODO: see how to make this simpler
	<<I:Size/integer-signed>> = Bin, % big-endian
	I;
decode_int(text,Bin) ->
	list_to_integer(binary_to_list(Bin)).
	
	

decode_float(binary,Bin) ->
	Size = bit_size(Bin),  %%TODO: see how to make this simpler
 	<<F:Size/float>> = Bin,
 	F;


decode_float(text,Bin) ->
	list_to_float(binary_to_list(Bin)).


decode_date(binary,<<A:32/signed>>) ->
	Epoch = 730485, % postgres epoch, in gregorian days {2000,1,1}
	calendar:gregorian_days_to_date(Epoch + A);

%TODO: I think the <<"DateStyle">> property 
% in the server should be  <<"ISO">> for this
% text decoding to work correctly.
decode_date(text,<<YYYY:4/binary,$-,MM:2/binary,$-,DD:2/binary>>) ->
	{list_to_integer(binary_to_list(YYYY)),list_to_integer(binary_to_list(MM)),list_to_integer(binary_to_list(DD))}.



decode_timestamp(binary,<<I:64/integer-signed>>) ->
	Epoch =  63113904000, % postgres epoch, in gregorian seconds {{2000,1,1},{0,0,0}}
	TimeSeconds = (I div 1000000), %postgres store microseconds 
	calendar:gregorian_seconds_to_datetime(Epoch + TimeSeconds);
	
decode_timestamp(text,<<YYYY:4/binary,$-,MM:2/binary,$-,DD:2/binary,32,
						HH:2/binary,$:,MIN:2/binary,$:,SEC:2/binary>>) ->
	Date = {list_to_integer(binary_to_list(YYYY)),
	       list_to_integer(binary_to_list(MM)),
	       list_to_integer(binary_to_list(DD))},
	Time = {list_to_integer(binary_to_list(HH)),
	       list_to_integer(binary_to_list(MIN)),
	       list_to_integer(binary_to_list(SEC))},
	{Date,Time}.
	       

% decode_timetz() -> 
% decode_timestamptz()
% decode_timestamp()
% decode_time()



raw_decoder(_,Bin) -> Bin.


default_decoder() -> fun raw_decoder/2.