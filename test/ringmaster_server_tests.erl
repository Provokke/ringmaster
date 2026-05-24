-module(ringmaster_server_tests).
-include_lib("eunit/include/eunit.hrl").

server_test() ->
    {ok, Pid} = ringmaster_server:start_link(64),
    ?assertEqual({error, empty}, ringmaster_server:lookup(Pid, k)),
    ok = ringmaster_server:add(Pid, a),
    ok = ringmaster_server:add(Pid, b),
    ?assertEqual([a, b], ringmaster_server:nodes(Pid)),
    ?assertMatch({ok, _}, ringmaster_server:lookup(Pid, k)),
    ?assertEqual(2, length(ringmaster_server:replicas(Pid, k, 2))),
    ok = ringmaster_server:remove(Pid, a),
    ?assertEqual({ok, b}, ringmaster_server:lookup(Pid, k)),
    ringmaster_server:stop(Pid).

