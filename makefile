default: saio.pem
kmip: kmip-server.pem kmip-client.pem
.PHONY: default info clean kmip

info:
	[ ! -f ca.crt ] || openssl x509 -text -noout -in ca.crt
	[ ! -f saio.csr ] || openssl req -text -noout -in saio.csr
	[ ! -f saio.pem ] || openssl x509 -text -noout -in saio.pem
	[ ! -f kmip-server.pem ] || openssl x509 -text -noout -in kmip-server.pem
	[ ! -f kmip-client.pem ] || openssl x509 -text -noout -in kmip-client.pem

%.key:
	@echo
	@echo "Creating key file $@"
	#openssl genrsa -out $@ 2048
	openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:secp521r1 -pkeyopt ec_param_enc:explicit -out $@

ca.crt: ca.conf ca.key
	@echo
	@echo "Creating self-signed CA certificate"
	openssl req -sha512 -new -x509 -config $< -key ca.key -days 3650 -out $@

%.csr: %.conf %.key
	@echo
	@echo "Creating certificate request $@"
	openssl req -new -config $*.conf -key $*.key -out $@

%.crt: ca.crt %.csr %.conf
	@echo
	@echo "Signing certificate %@"
	[ -f ca.srl ] || date '+%s' > ca.srl
	openssl x509 -CA ca.crt -CAkey ca.key \
	-extfile $*.conf -extensions ext -days 365 \
	-sha512 -req -in $*.csr -out $@

%.pem: %.crt %.key
	@echo
	@echo "Creating certificate+key PEM file $@"
	cat $^ > $@

clean:
	rm -f ca.key ca.crt ca.pem ca.srl
	rm -f saio.key saio.csr saio.crt saio.pem
	rm -f kmip-server.key kmip-server.csr kmip-server.crt kmip-server.pem
	rm -f kmip-client.key kmip-client.csr kmip-client.crt kmip-client.pem
