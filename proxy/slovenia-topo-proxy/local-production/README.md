# Local Production Setup

This setup makes `https://tiles.peakbagger.com/slovenia-topo/{z}/{x}/{y}.png`
work on the local machine by:

- running the Dart Slovenia proxy on `127.0.0.1:8080`
- terminating HTTPS in Apache on `tiles.peakbagger.com`
- overriding local hostname resolution to `127.0.0.1`

This keeps the app on the production URL contract while serving tiles locally.

## Target Caveats

- macOS app: supported by this setup
- iOS simulator: usually works with the host Mac setup
- Android emulator: does not use the Mac `/etc/hosts`; use the app's debug override instead
- physical devices: need real DNS or device-local host mapping and trusted TLS, not just Mac `/etc/hosts`

## Files In This Folder

- `apache/tiles.peakbagger.com.conf`: Apache vhost and reverse proxy config
- `launchd/com.peakbagger.slovenia-topo-proxy.plist`: auto-start the Dart proxy at login

## Prerequisites

1. Apache with `ssl`, `proxy`, `proxy_http`, and `headers` modules available
2. Dart installed
3. `mkcert` installed for a locally trusted certificate

Example install commands on macOS with Homebrew:

```bash
brew install httpd mkcert
mkcert -install
```

## 1. Create A Local Certificate

From the repo root:

```bash
mkdir -p proxy/slovenia-topo-proxy/local-production/certs
mkcert \
  -cert-file proxy/slovenia-topo-proxy/local-production/certs/tiles.peakbagger.com.pem \
  -key-file proxy/slovenia-topo-proxy/local-production/certs/tiles.peakbagger.com-key.pem \
  tiles.peakbagger.com
```

## 2. Map The Hostname Locally

Append this line to `/etc/hosts`:

```text
127.0.0.1 tiles.peakbagger.com
```

Example:

```bash
printf '\n127.0.0.1 tiles.peakbagger.com\n' | sudo tee -a /etc/hosts
```

## 3. Install The LaunchAgent

Copy the provided plist into `~/Library/LaunchAgents/`:

```bash
mkdir -p ~/Library/LaunchAgents
cp proxy/slovenia-topo-proxy/local-production/launchd/com.peakbagger.slovenia-topo-proxy.plist \
  ~/Library/LaunchAgents/
```

Load it:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.peakbagger.slovenia-topo-proxy.plist 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.peakbagger.slovenia-topo-proxy.plist
```

Check status:

```bash
launchctl print gui/$(id -u)/com.peakbagger.slovenia-topo-proxy
```

Proxy logs will be written to:

- `~/Library/Logs/peakbagger-slovenia-topo-proxy.out.log`
- `~/Library/Logs/peakbagger-slovenia-topo-proxy.err.log`

## 4. Install The Apache Config

Copy `apache/tiles.peakbagger.com.conf` into your Apache include path.

For Homebrew Apache on Apple Silicon this is commonly:

```bash
sudo cp proxy/slovenia-topo-proxy/local-production/apache/tiles.peakbagger.com.conf /opt/homebrew/etc/httpd/extra/
```

Then include it from Apache's main config if not already included:

```apache
Include /opt/homebrew/etc/httpd/extra/tiles.peakbagger.com.conf
```

If you are using a different Apache install, adjust the include path accordingly.

## 5. Ensure Required Apache Modules Are Enabled

Your Apache config must load:

```apache
LoadModule ssl_module lib/httpd/modules/mod_ssl.so
LoadModule proxy_module lib/httpd/modules/mod_proxy.so
LoadModule proxy_http_module lib/httpd/modules/mod_proxy_http.so
LoadModule headers_module lib/httpd/modules/mod_headers.so
```

The exact paths vary by Apache installation.

## 6. Start Or Restart Apache

Homebrew Apache:

```bash
brew services restart httpd
```

Or directly:

```bash
sudo apachectl -k restart
```

## 7. Verify End To End

Verify the proxy itself:

```bash
curl -I http://127.0.0.1:8080/slovenia-topo/16/35325/23389.png
```

Verify the production hostname locally:

```bash
curl -I https://tiles.peakbagger.com/slovenia-topo/16/35325/23389.png
```

Expected result for both: `HTTP/1.1 200 OK`

## Troubleshooting

`Could not resolve host: tiles.peakbagger.com`:

- re-check `/etc/hosts`
- flush DNS cache if needed:

```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

`SSL certificate problem`:

- re-run `mkcert -install`
- ensure Apache config points at the generated cert and key files

`502` from Apache:

- the Dart proxy is not running or is not reachable on `127.0.0.1:8080`
- inspect `~/Library/Logs/peakbagger-slovenia-topo-proxy.err.log`

`502` from the Dart proxy:

- upstream Slovenia WMS is failing or rate-limiting
- the tuned proxy defaults in `lib/src/tile_handler.dart` are already reduced to lower fan-out pressure

## Reverting

Unload the LaunchAgent:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.peakbagger.slovenia-topo-proxy.plist
```

Remove the `/etc/hosts` line and restart Apache.
