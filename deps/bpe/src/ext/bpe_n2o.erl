-module(bpe_n2o).
-include_lib("bpe/include/bpe.hrl").
-include_lib("bpe/include/doc.hrl").
-record('Token', {data= [] :: binary()}).
-record(io, {code= [] :: term(),data = [] :: [] | #'Token'{} | #process{} | #io{} | term() }).
-export([info/3]).

info(#'Amen'{id=Proc,docs=Docs},R,S) -> {reply,{bert,#io{data=bpe:amend(binary_to_list(Proc),Docs)}},R,S};
info(#'Hist'{id=Proc},R,S) -> {reply,{bert,#io{data=bpe:hist(binary_to_list(Proc))}},  R,S};
info(#'Proc'{id=Proc},R,S) -> {reply,{bert,#io{data=bpe:proc(binary_to_list(Proc))}},  R,S};
info(#'Load'{id=Proc},R,S) -> {reply,{bert,#io{data=bpe:load(binary_to_list(Proc))}},  R,S};
info(#'Next'{id=Proc},R,S) -> {reply,{bert,#io{data=bpe:next(binary_to_list(Proc))}},  R,S};
info(#'Make'{proc=M,docs=Docs},R,S) -> {reply,{bert,#io{data=bpe:start((nitro:to_atom(M)):def(),Docs)}},R,S};
info(M,R,S) -> {unknown,M,R,S}.
