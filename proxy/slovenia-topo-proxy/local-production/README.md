# Local Production Setup

This setup makes `https://tiles.peakbagger.com/slovenia-topo/{z}/{x}/{y}.png`
work on the local machine by:

- running the Dart Slovenia proxy on `127.0.0.1:8080`
- terminating HTTPS in Apache on `tiles.peakbagger.com`
- overriding local hostname resolution to `127.0.0.1`

This keeps the app on the production URL contract while serving tiles locally.

## Target

- macOS app only

## Files In This Folder

- `apache/tiles.peakbagger.com.conf`: Apache vhost and reverse proxy config
- `launchd/com.peakbagger.slovenia-topo-proxy.plist`: auto-start the Dart proxy at login
- `scripts/setup-local-production.sh`: first-time machine setup
- `scripts/restart-local-production.sh`: refresh installed files and restart Apache + proxy

## Script Entry Points

From the repo root:

```bash
bash proxy/slovenia-topo-proxy/local-production/scripts/setup-local-production.sh
```

After later machine restarts or local config changes:

```bash
bash proxy/slovenia-topo-proxy/local-production/scripts/restart-local-production.sh
```

The scripts render machine-specific copies of the Apache vhost and `launchd`
plist from the checked-in files, so they stay aligned with the actual repo path
and home directory on the current machine.

## Prerequisites

1. The built-in macOS Apache at `/usr/sbin/httpd`
2. Dart installed
3. `mkcert` installed for a locally trusted certificate

This machine is using:

```bash
which httpd
which apachectl
apachectl -V
```

Expected paths on this machine:

```text
/usr/sbin/httpd
/usr/sbin/apachectl
/private/etc/apache2/httpd.conf
/private/etc/apache2/other/*.conf
/private/var/log/apache2/
```

Install `mkcert` if needed:

```bash
brew install mkcert
mkcert -install
```

## 1. Create A Local Certificate

If you are using the setup script, it will create the certificate for you. The
manual steps are below for visibility.

From the repo root:

```bash
mkdir -p proxy/slovenia-topo-proxy/local-production/certs
mkcert \
  -cert-file proxy/slovenia-topo-proxy/local-production/certs/tiles.peakbagger.com.pem \
  -key-file proxy/slovenia-topo-proxy/local-production/certs/tiles.peakbagger.com-key.pem \
  tiles.peakbagger.com
```

## 2. Map The Hostname Locally

If you are using the setup script, it will add the `/etc/hosts` entry if it is
missing.

Append this line to `/etc/hosts`:

```text
127.0.0.1 tiles.peakbagger.com
```

Example:

```bash
printf '\n127.0.0.1 tiles.peakbagger.com\n' | sudo tee -a /etc/hosts
```

## 3. Install The LaunchAgent

If you are using the scripts, they will render and install the `launchd` plist
for the current machine automatically.

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

If you are using the scripts, they will render and install the Apache vhost for
the current machine automatically.

Copy `apache/tiles.peakbagger.com.conf` into your Apache include path.

This Apache install already includes `/private/etc/apache2/other/*.conf`, so
copy the file there:

```bash
sudo cp proxy/slovenia-topo-proxy/local-production/apache/tiles.peakbagger.com.conf /private/etc/apache2/other/
```

No extra `Include` line is needed because `/private/etc/apache2/httpd.conf`
already includes `/private/etc/apache2/other/*.conf`.

## 5. Ensure Required Apache Modules Are Enabled

If you are using the setup script, it will uncomment the required module lines
in `/private/etc/apache2/httpd.conf` for you.

On this machine, `headers_module` is already loaded, but these modules are still
commented out in `/private/etc/apache2/httpd.conf` and must be enabled:

```apache
#LoadModule proxy_module libexec/apache2/mod_proxy.so
#LoadModule proxy_http_module libexec/apache2/mod_proxy_http.so
#LoadModule ssl_module libexec/apache2/mod_ssl.so
```

Edit `/private/etc/apache2/httpd.conf` and uncomment them so they become:

```apache
LoadModule proxy_module libexec/apache2/mod_proxy.so
LoadModule proxy_http_module libexec/apache2/mod_proxy_http.so
LoadModule ssl_module libexec/apache2/mod_ssl.so
```

You do not need to enable `httpd-ssl.conf` for this setup.

## 6. Start Or Restart Apache

The setup and restart scripts both do this for you.

```bash
sudo apachectl -k restart
```

If Apache is not running yet:

```bash
sudo apachectl start
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

`Invalid command 'SSLEngine'` or `Invalid command 'ProxyPass'`:

- one or more of `ssl_module`, `proxy_module`, or `proxy_http_module` is still commented out in `/private/etc/apache2/httpd.conf`

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
