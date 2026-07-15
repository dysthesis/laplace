def node_name:
  .given_name // .name;

def clean_tags:
  (.tags // []) | map(sub("^tag:"; "")) | sort;

. as $live
| ($live | map(node_name) | group_by(.) | map(select(length > 1) | .[0])) as $duplicates
| ($ssot
  | to_entries
  | map({
      key: .key,
      value: {
        tags: (.value.tags | sort),
        addresses: ([.value.ip, .value.ip6] | sort)
      }
    })
  | from_entries) as $want
| ($live | map({
    key: node_name,
    value: {
      tags: clean_tags,
      addresses: ((.ip_addresses // []) | sort)
    }
  }) | from_entries) as $have
| ($want
  | to_entries[]
  | .key as $host
  | .value as $expected
  | $have[$host] as $actual
  | if $actual == null then
      "MISSING from tailnet: \($host)"
    else
      [
        if $actual.tags != $expected.tags then
          "TAG DRIFT \($host): live=\($actual.tags | join(",")) ssot=\($expected.tags | join(","))"
        else empty end,
        if $actual.addresses != $expected.addresses then
          "ADDRESS DRIFT \($host): live=\($actual.addresses | join(",")) ssot=\($expected.addresses | join(","))"
        else empty end
      ][]
    end),
  ($have
  | to_entries[]
  | select((.value.tags | length) > 0 and $want[.key] == null)
  | "UNEXPECTED tagged tailnet node: \(.key)"),
  ($duplicates[] | "DUPLICATE tailnet node identity: \(.)")
