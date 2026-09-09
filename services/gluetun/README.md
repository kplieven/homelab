## Gluetun (VPN)

A standalone stack whose only job is to hold the VPN tunnel. It is deliberately
separate from the stacks that use it, because more than one of them does:

| Consumer | Stack | WebUI port |
| :-- | :-- | :-- |
| `qbittorrent` | [`../media-stack`](../media-stack) | `8080` |
| `mam` | [`../books-stack`](../books-stack) | `8089` |
| `seedboxapi` | [`../books-stack`](../books-stack) | — |

Those containers set `network_mode: "container:gluetun"`, which puts them inside
gluetun's network namespace: they get its interfaces, its routing table (a
`0.0.0.0/1` + `128.0.0.0/1` pair that overrides the default route onto `tun0`)
and its firewall killswitch.

> **A shared docker network is not a substitute.** Joining containers to a common
> network gives them name resolution and reachability — it does **not** change
> their default route. A container merely networked with gluetun still egresses
> through its own bridge to the host's WAN, with the real IP and no killswitch.
> Only namespace sharing routes the traffic.

To verify the tunnel actually carries a consumer's traffic, compare it against
the host:

```sh
curl -s https://ipinfo.io/ip                 # host: your ISP address
docker exec mam curl -s https://ipinfo.io/ip # should be the VPN address
```

---

## This stack publishes its consumers' ports

A container with no network stack of its own cannot publish a port from its own
compose file. Every port belonging to a namespace consumer is therefore mapped
here, in `docker-compose.yml`, not in the stack that defines the container.
Keep that list in sync when a consumer's WebUI port changes.

---

## After recreating gluetun: `restart-dependents.sh`

The namespace is pinned by container **ID**, not by name. Recreating gluetun —
an image pull, a `compose up` after an edit — leaves every consumer attached to
an ID that no longer exists. The failure is silent and nasty: the containers keep
reporting `running` while having no network at all, and their WebUIs go dead.

`docker restart` **cannot** repair this. The dead ID is baked into the
container's `HostConfig`, so a restart just retries the same doomed join. Only
recreating re-resolves `container:gluetun` from name to live ID, which means
going through each consumer's own compose stack — which is exactly what
`restart-dependents.sh` does. It discovers consumers from their compose labels,
groups them by project, and recreates them.

```sh
docker compose up -d --force-recreate   # anything that recreates gluetun
./restart-dependents.sh                 # then always this
```

Compose used to handle this automatically, back when the consumers lived in the
same project as gluetun. Now that they are spread across two stacks, nothing
does.

---

## Environment Variables

| Variable | Description |
| :-- | :-- |
| `VPN_SERVICE_PROVIDER` | VPN provider (see the [gluetun wiki](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers)). |
| `VPN_TYPE` | `openvpn` or `wireguard`. |
| `OPENVPN_USER` / `OPENVPN_PASSWORD` | OpenVPN credentials. |
| `GLUETUN_URL` | Control-server URL for the homepage widget. |
| `GLUETUN_API_KEY` | Control-server API key for the homepage widget. |
| `TZ` | Timezone (TZ identifier). |

Since gluetun v3.40 every control-server route is private by default, so the
homepage widget needs an API key role granting `GET /v1/publicip/ip`. That role
is defined in `auth/config.toml`.
