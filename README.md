<div align="center">

# ringmaster

A consistent hash ring with virtual nodes for Erlang, with an optional `gen_server` wrapper. No dependencies beyond OTP.

![License](https://img.shields.io/badge/LICENSE-MIT-blue?style=for-the-badge)  ![Language](https://img.shields.io/badge/ERLANG-A90533?style=for-the-badge&logo=erlang&logoColor=white)  ![Tests](https://img.shields.io/badge/TESTS-9-brightgreen?style=for-the-badge)

Refer to [LICENSE](LICENSE) for the legal bits.

</div>

## What's in it

- `ringmaster_ring`, a pure functional ring. Add and remove nodes, look up the owner of a key, or take the first N distinct nodes clockwise from it, which is the usual way to pick replicas.
- Virtual nodes, 128 per node by default, to even out the load.
- Keys and node names can be any Erlang term.
- `ringmaster_server`, a `gen_server` that holds a ring for callers who want a process.

```erlang
Ring0 = ringmaster_ring:new(),
Ring1 = lists:foldl(fun ringmaster_ring:add/2, Ring0, [node_a, node_b, node_c]),
{ok, Owner} = ringmaster_ring:lookup(<<"user:42">>, Ring1),
Replicas = ringmaster_ring:replicas(<<"user:42">>, 2, Ring1).
```

The server version:

```erlang
{ok, Pid} = ringmaster_server:start_link(),
ok = ringmaster_server:add(Pid, node_a),
{ok, node_a} = ringmaster_server:lookup(Pid, <<"k">>).
```

## 🏗️ Architecture

```
 ringmaster_server  (gen_server, state = a ring)
   add / remove / nodes / lookup / replicas  ── calls ──┐
                                                         ▼
 ringmaster_ring    #ring{vnodes, members, points}
   add/remove ─▶ rebuild: [{hash({Node, I}), Node} || Node <- Members, I <- 1..VNodes]
                          lists:sort ─▶ points
   lookup/replicas ─▶ hash(Key) ─▶ split points at the hash
                      ─▶ walk clockwise (From ++ Before), keep first N distinct nodes
   hash(Term) = first 32 bits of md5(term_to_binary(Term))
```

- The ring is an opaque record. `points` is a sorted list of `{Hash, Node}` pairs, rebuilt on every add or remove and searched linearly.
- `replicas/3` starts at the first point at or after the key's hash, wraps round the end of the list, and skips nodes it has already collected. Asking for more replicas than there are nodes returns every node once.
- `add/2` is idempotent. An empty ring returns `{error, empty}` from `lookup/2` and `[]` from `replicas/3`.
- Because only the points belonging to a node move, removing a node only reassigns the keys that node owned.

## 🚀 Quick start

```
rebar3 eunit
```

Needs OTP with `crypto`, and rebar3. The code builds with `warnings_as_errors`. With three nodes on the ring:

```erlang
ringmaster_ring:lookup(<<"user:42">>, Ring1).
ringmaster_ring:replicas(<<"user:42">>, 2, Ring1).
```

```
{ok,node_b}
[node_b,node_c]
```

## 🧪 Testing

9 EUnit tests, all passing:

- `ringmaster_ring` (8): an empty ring, lookups being stable, `add` being idempotent, `remove`, replicas being distinct, replicas capped by the number of members, removal only moving the removed node's keys, and distribution balance.
- `ringmaster_server` (1): the server end to end (empty lookup, add, nodes, lookup, replicas, remove).

The balance test allows a spread of 30 percent around the ideal share per node, so it's a loose check rather than a statistical one.

## ⚠️ Honest limits

- Rebuilding and linear search are fine for tens of nodes and a few hundred virtual nodes each, but not for very large rings.
- No weighting and no persistence.

## Licence

MIT.

