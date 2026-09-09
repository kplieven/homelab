# Caddy needs the Cloudflare DNS provider for the `tls { dns cloudflare }`
# directive used by the (cloudflare) snippet in the Caddyfile, so it has to be
# built with xcaddy rather than pulled from the stock image.
FROM caddy:2-builder AS builder

RUN xcaddy build --with github.com/caddy-dns/cloudflare

FROM caddy:2

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
