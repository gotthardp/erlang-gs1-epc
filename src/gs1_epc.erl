%
% The contents of this file are subject to the Mozilla Public License
% Version 1.1 (the "License"); you may not use this file except in
% compliance with the License. You may obtain a copy of the License at
% http://www.mozilla.org/MPL/
%
% Copyright (c) 2016 Petr Gotthard <petr.gotthard@centrum.cz>
%

% encoding and decoding for GS1 EPC/RFID
-module(gs1_epc).

-export([tag_to_binary/1, binary_to_tag/1]).

-define(EPC_SGTIN_96,  2#00110000).
-define(EPC_SGTIN_198, 2#00110110).
-define(EPC_SSCC_96,   2#00110001).
-define(EPC_SGLN_96,   2#00110010).
-define(EPC_SGLN_195,  2#00111001).
-define(EPC_GRAI_96,   2#00110011).
-define(EPC_GRAI_170,  2#00110111).
-define(EPC_GIAI_96,   2#00110100).
-define(EPC_GIAI_202,  2#00111000).
-define(EPC_GSRN_96,   2#00101101).
-define(EPC_GSRNP_96,  2#00101110).
-define(EPC_GDTI_96,   2#00101100).
-define(EPC_GDTI_113,  2#00111010).
-define(EPC_GDTI_174,  2#00111110).
-define(EPC_CPI_96,    2#00111100).
-define(EPC_CPI_var,   2#00111101).
-define(EPC_SGCN_96,   2#00101100).
-define(EPC_GID_96,    2#00110101).
-define(EPC_ADI_var,   2#00111011).

tag_to_binary({sgtin96, F, C, I, S}) ->
    <<?EPC_SGTIN_96, F:3, (sgtin_join(C, I))/bitstring, (list_to_integer(S)):38>>;

tag_to_binary({sgtin198, F, C, I, S}) ->
    S2 = enc_7string(S),
    <<?EPC_SGTIN_198, F:3, (sgtin_join(C, I))/bitstring, S2/bitstring, 0:(142-bit_size(S2))>>;

tag_to_binary(Unknown) ->
    {error, Unknown}.


binary_to_tag(<<?EPC_SGTIN_96, F:3, P:47/bitstring, S:38>>) ->
    {C, I} = sgtin_parition(P),
    {sgtin96, F, C, I, integer_to_list(S)};

binary_to_tag(<<?EPC_SGTIN_198, F:3, P:47/bitstring, S:140/bitstring, _/bitstring>>) ->
    {C, I} = sgtin_parition(P),
    {sgtin198, F, C, I, dec_7string(S, [])};

binary_to_tag(<<T, R/binary>>) ->
    {error, T, bit_size(R)}.


% Table 14-2
sgtin_parition(<<0:3, C:40, I:4>>) ->  {dig(C, 12), dig(I, 1)};
sgtin_parition(<<1:3, C:37, I:7>>) ->  {dig(C, 11), dig(I, 2)};
sgtin_parition(<<2:3, C:34, I:10>>) -> {dig(C, 10), dig(I, 3)};
sgtin_parition(<<3:3, C:30, I:14>>) -> {dig(C, 9),  dig(I, 4)};
sgtin_parition(<<4:3, C:27, I:17>>) -> {dig(C, 8),  dig(I, 5)};
sgtin_parition(<<5:3, C:24, I:20>>) -> {dig(C, 7),  dig(I, 6)};
sgtin_parition(<<6:3, C:20, I:24>>) -> {dig(C, 6),  dig(I, 7)}.

sgtin_join(C, I) ->
    sgtin_join2(list_to_integer(C), length(C), list_to_integer(I), length(I)).

sgtin_join2(C, 12, I, 1) -> <<0:3, C:40, I:4>>;
sgtin_join2(C, 11, I, 2) -> <<1:3, C:37, I:7>>;
sgtin_join2(C, 10, I, 3) -> <<2:3, C:34, I:10>>;
sgtin_join2(C, 9,  I, 4) -> <<3:3, C:30, I:14>>;
sgtin_join2(C, 8,  I, 5) -> <<4:3, C:27, I:17>>;
sgtin_join2(C, 7,  I, 6) -> <<5:3, C:24, I:20>>;
sgtin_join2(C, 6,  I, 7) -> <<6:3, C:20, I:24>>.


% decode a string of 7-bit segments
enc_7string(S) ->
    enc_7string(lists:reverse(S), <<>>).

enc_7string([C|R], Acc) ->
    enc_7string(R, <<C:7, Acc/bitstring>>);
enc_7string([], Acc) ->
    Acc.

% decode a string of 7-bit segments
dec_7string(<<0:7, _R/bitstring>>, Acc) ->
    % all segments following a zero segment must be zeros
    lists:reverse(Acc);
dec_7string(<<>>, Acc) ->
    lists:reverse(Acc);
dec_7string(<<C:7, R/bitstring>>, Acc) ->
    dec_7string(R, [C|Acc]).

% convert integer to list with a fixed number of digits
dig(N, D) ->
    string:right(integer_to_list(N), D, $0).

-include_lib("eunit/include/eunit.hrl").

% Annex E.3
codec_test_()-> [
    coder({sgtin96,3,"0614141","812345","6789"}, hex2b("3074257BF7194E4000001A85")),
    coder({sgtin198,3,"0614141","712345","32a/b"}, hex2b("3674257BF6B7A659B2C2BF1000000000000000000000000000"))].

coder(Tag, Bin) ->
    [?_assertEqual(Tag, binary_to_tag(Bin)),
    ?_assertEqual(Bin, tag_to_binary(Tag))].

% convert a hex-string to an erlang binary
hex2b(S) -> hex2b(lists:reverse(S), <<>>).

hex2b([X2,X1|Rest], Acc) -> hex2b(Rest, <<(list_to_integer([X1,X2], 16)), Acc/binary>>);
hex2b([], Acc) -> Acc.

% end of file
