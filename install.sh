if [[ -z $1 ]];then
	RELEASE="2026.1/edge"
else
	RELEASE=$1
fi

sudo snap install openstack --channel $RELEASE

sunbeam prepare-node-script --bootstrap | bash -x && newgrp snap_daemon

sunbeam cluster bootstrap --role compute,control,storage --accept-defaults
sunbeam configure --openrc demo-openrc --accept-defaults
sunbeam openrc > admin_openrc
source ./admin_openrc 
echo $OS_PASSWORD
echo $OS_USER_DOMAIN_NAME

sunbeam enable vault
sunbeam vault init  5 3 > ./vault_keys
sudo chattr +i ./vault_keys

for each in $(grep -A 5 Unseal ./vault_keys | tail +2); do sunbeam vault unseal $each; done
sunbeam vault authorize-charm $(grep Root ./vault_keys | cut -d: -f2)

sunbeam enable secrets
sunbeam enable tls self-signed --endpoint public --endpoint internal --endpoint rgw

sunbeam enable loadbalancer

mkdir certs
openssl genrsa -out certs/ca.key 2048
openssl req -new -x509 -days 3650 -key certs/ca.key -out certs/ca.crt -subj "/C=GB/CN=lab.lan"

cd certs

# Create leaf.ext
cat << EOF > ./leaf.ext
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
EOF

# Create ca_ext.ext
cat << EOF > ./ca_ext.ext
basicConstraints = critical, CA:TRUE, pathlen:0
keyUsage = critical, keyCertSign, cRLSign
EOF


# Get cert singing requests for Octavia
sunbeam loadbalancer list_outstanding_csrs --format yaml | yq '.[]' - -r --split-exp=' .endpoint + ".csr.yaml"' 

# two step process... to be improved...
for each in $(ls ./amphora*.csr.yaml)
do
  yq ' .csr ' $each > ./$(basename $each .yaml)
done


# Sign the controller
openssl x509 -req -days 365 \
  -in amphora-controller-cert.csr \
  -CA ca.crt -CAkey ca.key -CAserial ca.srl \
  -out amphora-controller-cert.crt \
  -extfile leaf.ext

# Sign the issuer
openssl x509 -req -days 730 \
  -in amphora-issuing-ca.csr \
  -CA ca.crt -CAkey ca.key -CAserial ca.srl \
  -out amphora-issuing-ca.crt \
  -extfile ca_ext.ext

for each in $(ls ./*.crt)
do
  echo "$each: $(base64 -w0 $each)"
done

cd -



sunbeam enable caas
