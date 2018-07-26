saio-tls
========

A `make`-based approach to creating TLS certificates appropriate for a
[Swift-All-In-One](https://github.com/swiftstack/vagrant-swift-all-in-one).

Getting Started
---------------

1. Generate certificates

   ```
   make
   ```

   The most interesting results are
   * `saio.pem` -- contains the combined key and certificate
                   suitable for a host named "saio"
   * `ca.crt` -- contains the signing certificate for use by clients

1. Update proxy-server.conf

   * Add `require_proxy_protocol = yes` to the `[app:proxy-server]` section.
   * Restart the proxy server.

1. Run an SSL terminator

   * haproxy
     ```
     cat << EOF > haproxy.conf
     global
         tune.ssl.default-dh-param 4096

     defaults
         timeout connect 100ms
         timeout client   60s
         timeout server   60s

     listen https-in
         bind *:443 ssl crt saio.pem
         server saio 127.0.0.1:8080 send-proxy
     EOF

     sudo haproxy -f haproxy.conf
     ```

   * stunnel

     ```
     cat << EOF > stunnel.conf
     foreground = yes

     [saio]
     accept     = 443
     cert       = saio.pem
     connect    = 8080
     protocol   = proxy
     EOF

     sudo stunnel stunnel.conf
     ```

   * hitch

     ```
     cat << EOF > hitch.conf
     quiet           = on
     write-proxy-v1  = on
     frontend        = "[*]:443+saio.pem"
     backend         = "[127.0.0.1]:8080"
     user            = "nobody"
     group           = "nogroup"
     EOF

     sudo hitch --config hitch.conf
     ```

1. Update test.conf (if running functional tests)

   ```
   [func_test]
   insecure = yes
   auth_ssl = yes
   auth_host = 127.0.0.1
   auth_port = 443
   auth_prefix = /auth/
   ```

Testing with PyKMIP
-------------------

1. Generate certificates

   ```
   make kmip
   ```

1. Start KMIP server

   ```
   mkdir -p pykmip-policies
   mkdir -p /var/log/pykmip
   cat << EOF > pykmip-server.conf
   [server]
   hostname = 127.0.0.1
   port = 5696
   ca_path=ca.crt
   certificate_path=kmip-server.pem
   key_path=kmip-server.pem
   auth_suite = TLS1.2
   policy_path = pykmip-policies
   logging_level=DEBUG
   EOF
   python -m kmip.services.server.server -f pykmip-server.conf &
   ```

1. Configure KMIP client

   ```
   cat << EOF > pykmip-client.conf
   [client]
   host = 127.0.0.1
   port = 5696
   ca_certs = ca.crt
   certfile = kmip-client.pem
   keyfile = kmip-client.pem
   EOF
   ```

1. Create AES-256 key

   ```
   python -m kmip.demos.pie.create -a AES -l 256 -s pykmip-client.conf
   ```

---

#### Why include a certificate authority? Why not just use self-signed certificates?

By including a long-lived CA certificate, you

1. can continue using the same certificate client-side (even adding
   it to your host machine's trusted certificates!) while periodically
   updating the server certificate, and
2. more accurately reflect the way in which certificates are issued
   and used in production.

To update the server's certificate, run `touch saio.config && make`
