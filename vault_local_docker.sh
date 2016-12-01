#!/bin/sh

HOST_VAULT_PORT=8200
HOST_VAULT_CERTS_DIR=/etc/vault/certs
HOST_VAULT_DATA_DIR=/var/lib/vault

mkdir -p $HOST_VAULT_CERTS_DIR && \
docker run --rm -e COMMON_NAME=mycert -e KEY_NAME=mycert -v $HOST_VAULT_CERTS_DIR:/certs:rw centurylink/openssl && \
docker rm -f vault && rm $HOST_VAULT_DATA_DIR/* -fr; \
docker run -d \
--name vault \
--cap-add=IPC_LOCK \
-e VAULT_LOCAL_CONFIG='{"backend": {"file": {"path": "/vault/file"}}, "listener": {"tcp":{"address":"0.0.0.0:8200", "tls_cert_file":"/vault/certs/mycert.crt", "tls_key_file":"/vault/certs/mycert.key"}}, "default_lease_ttl": "100000h", "max_lease_ttl": "100000h"}' \
-v $HOST_VAULT_CERTS_DIR:/vault/certs:rw \
-v $HOST_VAULT_DATA_DIR:/vault/file:rw \
-p $HOST_VAULT_PORT:8200 \
vault \
vault server -config=/vault/config && \
KEYS=$(docker run --rm --link vault vault vault init -tls-skip-verify -address=https://vault:8200) && \
docker run --rm -it --link vault vault vault unseal -tls-skip-verify -address=https://vault:8200 $(echo $KEYS | grep -Po '(?<=Unseal Key 1: )(.*)(?= Unseal Key 2)') && \
docker run --rm -it --link vault vault vault unseal -tls-skip-verify -address=https://vault:8200 $(echo $KEYS | grep -Po '(?<=Unseal Key 2: )(.*)(?= Unseal Key 3)') && \
docker run --rm -it --link vault vault vault unseal -tls-skip-verify -address=https://vault:8200 $(echo $KEYS | grep -Po '(?<=Unseal Key 3: )(.*)(?= Unseal Key 4)') && \
printf 'Your vault has been initialized!\nSave these credentials:\n' && \
echo $KEYS && \
printf 'Use "docker run --rm -it --link vault vault sh" to manage vault via vault cli\nAuthorization: "vault auth  -tls-skip-verify -address=https://vault:8200"\n' && \
KEYS=''
