#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/../../scripts/utils.sh

mkdir -p ${DIR}/ldap_certs
cd ${DIR}/ldap_certs
if [[ "$OSTYPE" == "darwin"* ]]
then
    # workaround for issue on linux, see https://github.com/vdesabou/kafka-docker-playground/issues/851#issuecomment-821151962
    chmod -R a+rw .
else
    # on CI, docker is run as runneradmin user, need to use sudo
    ls -lrt
    sudo chmod -R a+rw .
    ls -lrt
fi
log "LDAPS: Creating a Root Certificate Authority (CA)"
docker run --rm -v $PWD:/tmp vdesabou/kafka-docker-playground-connect:${CONNECT_TAG} openssl req -new -x509 -days 365 -nodes -out /tmp/ca.crt -keyout /tmp/ca.key -subj "/CN=root-ca"
log "LDAPS: Generate the LDAPS server key and certificate"
docker run --rm -v $PWD:/tmp vdesabou/kafka-docker-playground-connect:${CONNECT_TAG} openssl req -new -nodes -out /tmp/server.csr -keyout /tmp/server.key -subj "/CN=openldap"
docker run --rm -v $PWD:/tmp vdesabou/kafka-docker-playground-connect:${CONNECT_TAG} openssl x509 -req -in /tmp/server.csr -days 365 -CA /tmp/ca.crt -CAkey /tmp/ca.key -CAcreateserial -out /tmp/server.crt
log "LDAPS: Create a JKS truststore"
rm -f ldap_truststore.jks
# We import the test CA certificate
docker run --rm -v $PWD:/tmp vdesabou/kafka-docker-playground-connect:${CONNECT_TAG} keytool -import -v -alias testroot -file /tmp/ca.crt -keystore /tmp/ldap_truststore.jks -storetype JKS -storepass 'welcome123' -noprompt
log "LDAPS: Displaying truststore"
docker run --rm -v $PWD:/tmp vdesabou/kafka-docker-playground-connect:${CONNECT_TAG} keytool -list -keystore /tmp/ldap_truststore.jks -storepass 'welcome123' -v
cd -

${DIR}/../../environment/ldap-authorizer-sasl-plain/start.sh "${PWD}/docker-compose.ldap-authorizer-sasl-plain.ldaps.yml"

# FIXTHIS: does not work


# [2021-12-15 10:21:29,673] ERROR LDAP search failed, search will be retried. Groups from the last successful search will continue to be applied until the configured retry timeout or the next successful search. (io.confluent.security.auth.provider.ldap.LdapGroupManager)
# io.confluent.security.auth.provider.ldap.LdapException: LDAP context could not be created with provided configs
#         at io.confluent.security.auth.provider.ldap.LdapContextCreator.lambda$createLdapContext$0(LdapContextCreator.java:82)
#         at java.base/java.security.AccessController.doPrivileged(Native Method)
#         at java.base/javax.security.auth.Subject.doAs(Subject.java:361)
#         at io.confluent.security.auth.provider.ldap.LdapContextCreator.createLdapContext(LdapContextCreator.java:78)
#         at io.confluent.security.auth.provider.ldap.LdapGroupManager.searchAndProcessResults(LdapGroupManager.java:347)
#         at io.confluent.security.auth.provider.ldap.LdapGroupManager.start(LdapGroupManager.java:185)
#         at io.confluent.security.auth.provider.ldap.LdapGroupProvider.configure(LdapGroupProvider.java:32)
#         at io.confluent.security.authorizer.ConfluentAuthorizerConfig.lambda$createProviders$2(ConfluentAuthorizerConfig.java:167)
#         at java.base/java.lang.Iterable.forEach(Iterable.java:75)
#         at io.confluent.security.authorizer.ConfluentAuthorizerConfig.createProviders(ConfluentAuthorizerConfig.java:167)
#         at io.confluent.security.authorizer.EmbeddedAuthorizer.configureServerInfo(EmbeddedAuthorizer.java:96)
#         at io.confluent.kafka.security.authorizer.ConfluentServerAuthorizer.configureServerInfo(ConfluentServerAuthorizer.java:85)
#         at io.confluent.kafka.security.authorizer.ConfluentServerAuthorizer.start(ConfluentServerAuthorizer.java:148)
#         at kafka.server.KafkaServer.startup(KafkaServer.scala:553)
#         at kafka.Kafka$.main(Kafka.scala:108)
#         at kafka.Kafka.main(Kafka.scala)
# Caused by: javax.naming.CommunicationException: ldap3.confluent.io.:636 [Root exception is javax.net.ssl.SSLHandshakeException: Illegal given domain name: ldap3.confluent.io.]
#         at java.naming/com.sun.jndi.ldap.Connection.<init>(Connection.java:252)
#         at java.naming/com.sun.jndi.ldap.LdapClient.<init>(LdapClient.java:137)
#         at java.naming/com.sun.jndi.ldap.LdapClient.getInstance(LdapClient.java:1616)
#         at java.naming/com.sun.jndi.ldap.LdapCtx.connect(LdapCtx.java:2847)
#         at java.naming/com.sun.jndi.ldap.LdapCtx.<init>(LdapCtx.java:348)
#         at java.naming/com.sun.jndi.ldap.LdapCtxFactory.getLdapCtxFromUrl(LdapCtxFactory.java:262)
#         at java.naming/com.sun.jndi.ldap.LdapCtxFactory.getUsingURL(LdapCtxFactory.java:226)
#         at java.naming/com.sun.jndi.ldap.LdapCtxFactory.getUsingURLs(LdapCtxFactory.java:280)
#         at java.naming/com.sun.jndi.ldap.LdapCtxFactory.getLdapCtxInstance(LdapCtxFactory.java:185)
#         at java.naming/com.sun.jndi.ldap.LdapCtxFactory.getInitialContext(LdapCtxFactory.java:115)
#         at java.naming/javax.naming.spi.NamingManager.getInitialContext(NamingManager.java:730)
#         at java.naming/javax.naming.InitialContext.getDefaultInitCtx(InitialContext.java:305)
#         at java.naming/javax.naming.InitialContext.init(InitialContext.java:236)
#         at java.naming/javax.naming.ldap.InitialLdapContext.<init>(InitialLdapContext.java:154)
#         at io.confluent.security.auth.provider.ldap.LdapContextCreator.lambda$createLdapContext$0(LdapContextCreator.java:80)
#         ... 15 more
# Caused by: javax.net.ssl.SSLHandshakeException: Illegal given domain name: ldap3.confluent.io.
#         at java.base/sun.security.ssl.Alert.createSSLException(Alert.java:131)
#         at java.base/sun.security.ssl.TransportContext.fatal(TransportContext.java:349)
#         at java.base/sun.security.ssl.TransportContext.fatal(TransportContext.java:292)
#         at java.base/sun.security.ssl.TransportContext.fatal(TransportContext.java:287)
#         at java.base/sun.security.ssl.CertificateMessage$T12CertificateConsumer.checkServerCerts(CertificateMessage.java:654)
#         at java.base/sun.security.ssl.CertificateMessage$T12CertificateConsumer.onCertificate(CertificateMessage.java:473)
#         at java.base/sun.security.ssl.CertificateMessage$T12CertificateConsumer.consume(CertificateMessage.java:369)
#         at java.base/sun.security.ssl.SSLHandshake.consume(SSLHandshake.java:392)
#         at java.base/sun.security.ssl.HandshakeContext.dispatch(HandshakeContext.java:443)
#         at java.base/sun.security.ssl.HandshakeContext.dispatch(HandshakeContext.java:421)
#         at java.base/sun.security.ssl.TransportContext.dispatch(TransportContext.java:182)
#         at java.base/sun.security.ssl.SSLTransport.decode(SSLTransport.java:172)
#         at java.base/sun.security.ssl.SSLSocketImpl.decode(SSLSocketImpl.java:1426)
#         at java.base/sun.security.ssl.SSLSocketImpl.readHandshakeRecord(SSLSocketImpl.java:1336)
#         at java.base/sun.security.ssl.SSLSocketImpl.startHandshake(SSLSocketImpl.java:450)
#         at java.base/sun.security.ssl.SSLSocketImpl.startHandshake(SSLSocketImpl.java:421)
#         at java.naming/com.sun.jndi.ldap.Connection.createSocket(Connection.java:364)
#         at java.naming/com.sun.jndi.ldap.Connection.<init>(Connection.java:231)
#         ... 29 more
# Caused by: java.security.cert.CertificateException: Illegal given domain name: ldap3.confluent.io.
#         at java.base/sun.security.util.HostnameChecker.matchDNS(HostnameChecker.java:193)
#         at java.base/sun.security.util.HostnameChecker.match(HostnameChecker.java:103)
#         at java.base/sun.security.ssl.X509TrustManagerImpl.checkIdentity(X509TrustManagerImpl.java:459)
#         at java.base/sun.security.ssl.X509TrustManagerImpl.checkIdentity(X509TrustManagerImpl.java:429)
#         at java.base/sun.security.ssl.X509TrustManagerImpl.checkTrusted(X509TrustManagerImpl.java:229)
#         at java.base/sun.security.ssl.X509TrustManagerImpl.checkServerTrusted(X509TrustManagerImpl.java:129)
#         at java.base/sun.security.ssl.CertificateMessage$T12CertificateConsumer.checkServerCerts(CertificateMessage.java:638)
#         ... 42 more
# Caused by: java.lang.IllegalArgumentException: Server name value of host_name cannot have the trailing dot
#         at java.base/javax.net.ssl.SNIHostName.checkHostName(SNIHostName.java:319)
#         at java.base/javax.net.ssl.SNIHostName.<init>(SNIHostName.java:108)
#         at java.base/sun.security.util.HostnameChecker.matchDNS(HostnameChecker.java:191)
#         ... 48 more

# docker exec --privileged --user root -i broker yum install --disablerepo='Confluent*' bind-utils

# [appuser@connect ~]$ nslookup -type=SRV _ldap._tcp.confluent.io
# Server:         127.0.0.11
# Address:        127.0.0.11#53

# _ldap._tcp.confluent.io service = 20 75 636 ldap3.confluent.io.
# _ldap._tcp.confluent.io service = 10 50 636 ldap2.confluent.io.
# _ldap._tcp.confluent.io service = 10 50 636 ldap.confluent.io.


# dig SRV _ldap._tcp.confluent.io

# ; <<>> DiG 9.11.26-RedHat-9.11.26-6.el8 <<>> SRV _ldap._tcp.confluent.io
# ;; global options: +cmd
# ;; Got answer:
# ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 32891
# ;; flags: qr aa rd ra; QUERY: 1, ANSWER: 3, AUTHORITY: 1, ADDITIONAL: 5

# ;; OPT PSEUDOSECTION:
# ; EDNS: version: 0, flags:; udp: 4096
# ; COOKIE: ecd1e8994d344ea8b754abe861b9c5cc86388a1929e859d5 (good)
# ;; QUESTION SECTION:
# ;_ldap._tcp.confluent.io.       IN      SRV

# ;; ANSWER SECTION:
# _ldap._tcp.confluent.io. 604800 IN      SRV     10 50 636 ldap2.confluent.io.
# _ldap._tcp.confluent.io. 604800 IN      SRV     10 50 636 ldap.confluent.io.
# _ldap._tcp.confluent.io. 604800 IN      SRV     20 75 636 ldap3.confluent.io.

# ;; AUTHORITY SECTION:
# confluent.io.           604800  IN      NS      bind.confluent.io.

# ;; ADDITIONAL SECTION:
# ldap.confluent.io.      604800  IN      A       172.28.1.2
# ldap2.confluent.io.     604800  IN      A       172.28.1.3
# ldap3.confluent.io.     604800  IN      A       172.28.1.4
# bind.confluent.io.      604800  IN      A       172.28.1.1

# ;; Query time: 0 msec
# ;; SERVER: 127.0.0.11#53(127.0.0.11)
# ;; WHEN: Wed Dec 15 10:39:08 UTC 2021
# ;; MSG SIZE  rcvd: 276