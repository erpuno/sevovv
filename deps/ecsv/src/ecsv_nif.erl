-module(ecsv_nif).
-export([parser_init/1, parse/3, write/1, write_lines/1, test/0]).

-on_load(load_nifs/0).

-define(APPNAME, ecsv).
-define(LIBNAME, ecsv).

-spec parser_init(Opts :: ecsv:options()) -> ecsv:state().
parser_init(Opts) ->
    erlang:nif_error(not_loaded, [Opts]).

-spec parse(Input, State0, Acc0) -> Result when
    Input :: ecsv:input(),
    State0 :: ecsv:state(),
    Acc0 :: ecsv:rows(),
    Result :: {ok, Acc, State} | {error, Acc, Reason},
    Acc :: ecsv:rows(),
    State :: ecsv:state(),
    Reason :: any().
parse(Input, _, _) ->
    erlang:nif_error(not_loaded, [Input]).

-spec write_lines([ecsv:line()]) -> iolist().
write_lines(L) ->
    erlang:nif_error(not_loaded, [L]).

-spec write(ecsv:line()) -> iolist().
write(L) ->
    erlang:nif_error(not_loaded, [L]).

test() -> ok.

load_nifs() ->
    SoName = case code:priv_dir(?APPNAME) of
        {error, bad_name} ->
            case filelib:is_dir(filename:join(["..", priv])) of
                true ->
                    filename:join(["..", priv, ?LIBNAME]);
                _ ->
                    filename:join([priv, ?LIBNAME])
            end;
        Dir ->
            filename:join(Dir, ?LIBNAME)
    end,
    erlang:load_nif(SoName, 0),
    ok.
