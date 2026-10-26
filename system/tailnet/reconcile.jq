# Structured drift records: callers decide presentation; identities remain data.
def node_name: .given_name // .name;
def clean_tags: (.tags // []) | map(sub("^tag:"; "")) | sort;
. as $live
| ($live | map(node_name) | group_by(.) | map(select(length > 1) | .[0])) as $duplicates
| ($ssot | with_entries(.value |= {
    tags: (.tags | sort), addresses: ([.ip, .ip6] | sort)
  })) as $want
| ($live | map({key: node_name, value: {
    tags: clean_tags, addresses: ((.ip_addresses // []) | sort)
  }}) | from_entries) as $have
| [
    ($want | to_entries[] | .key as $node | .value as $expected
      | $have[$node] as $actual
      | if $actual == null then {kind: "missing", node: $node}
        else
          (if $actual.tags != $expected.tags then
            {kind: "tag-drift", node: $node, expected: $expected.tags, actual: $actual.tags}
          else empty end),
          (if $actual.addresses != $expected.addresses then
            {kind: "address-drift", node: $node, expected: $expected.addresses, actual: $actual.addresses}
          else empty end)
        end),
    ($have | to_entries[] | select((.value.tags | length) > 0 and $want[.key] == null)
      | {kind: "unexpected", node: .key}),
    ($duplicates[] | {kind: "duplicate", node: .})
  ]
