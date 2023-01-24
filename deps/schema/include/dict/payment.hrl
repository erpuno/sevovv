-ifndef(PAYMENT_HRL).
-define(PAYMENT_HRL, true).

-include_lib("dec/include/dec.hrl").

-type paymentType() :: fiat | crypto.

-record('Payment', { id = [] :: list(),
                     invoice = [] :: [] | term(),
                     account = [] :: term(),
                     subaccount = [] :: term(),
                     volume = [] :: [] | dec:money(),
                     price = {money,0,1} :: #money{},
                     instrument = [] :: term(),
                     type = [] :: paymentType(),
                     from = [] :: term(),
                     to = [] :: term() }).

-endif.
