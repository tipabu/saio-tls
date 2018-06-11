default: saio.pem
.PHONY: default info clean

info:
	[ ! -f ca.crt ] || openssl x509 -text -noout -in ca.crt
	[ ! -f saio.csr ] || openssl req -text -noout -in saio.csr
	[ ! -f saio.crt ] || openssl x509 -text -noout -in saio.crt

%.key:
	openssl genrsa -out $@ 2048

ca.crt: ca.conf ca.key
	@echo
	@echo "Creating self-signed CA certificate"
	openssl req -new -x509 -config $< -key ca.key -days 3650 -out $@

saio.csr: saio.conf saio.key
	@echo
	@echo "Creating SAIO certificate request"
	openssl req -new -config $< -key saio.key -out $@

saio.crt: ca.crt saio.csr saio.conf
	@echo
	@echo "Signing SAIO certificate"
	[ -f ca.srl ] || date '+%s' > ca.srl
	openssl x509 -CA ca.crt -CAkey ca.key \
	-extfile saio.conf -extensions ext -days 365 \
	-req -in saio.csr -out $@

saio.pem: saio.crt saio.key
	@echo
	@echo "Creating SAIO certificate+key PEM file"
	cat $^ > $@

clean:
	rm -f ca.key ca.crt ca.srl saio.key saio.csr saio.crt
