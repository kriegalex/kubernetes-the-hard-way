#!/bin/bash

network_id="kube-private"

# UTILS
wget -q --show-progress --https-only --timestamping \
  https://github.com/cloudflare/cfssl/releases/download/v1.4.1/cfssl_1.4.1_linux_amd64 \
  https://github.com/cloudflare/cfssl/releases/download/v1.4.1/cfssljson_1.4.1_linux_amd64

mv cfssl_1.4.1_linux_amd64 cfssl
mv cfssljson_1.4.1_linux_amd64 cfssljson
chmod +x cfssl cfssljson

sudo mv cfssl cfssljson /usr/local/bin/

cd $HOME
mkdir certs
cd certs

# CA
{

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CH",
      "L": "Fribourg",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Fribourg"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

}

# ADMIN
{

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CH",
      "L": "Fribourg",
      "O": "system:masters",
      "OU": "kriegalex",
      "ST": "Fribourg"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

}

# KUBELET CERT
for instance in kube-worker0 kube-worker1 kube-worker2; do
cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CH",
      "L": "Fribourg",
      "O": "system:nodes",
      "OU": "kriegalex",
      "ST": "Fribourg"
    }
  ]
}
EOF

EXTERNAL_IP=$(openstack server show ${instance} -f json | jq -r --arg network_name "$network_id" '.addresses[$network_name][1]')

INTERNAL_IP=$(openstack server show ${instance} -f json | jq -r --arg network_name "$network_id" '.addresses[$network_name][0]')

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${instance},${EXTERNAL_IP},${INTERNAL_IP} \
  -profile=kubernetes \
  ${instance}-csr.json | cfssljson -bare ${instance}
done

# KUBE-CONTROLLER-MANAGER
{

cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CH",
      "L": "Fribourg",
      "O": "system:kube-controller-manager",
      "OU": "kriegalex",
      "ST": "Fribourg"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

}

# KUBE-PROXY
{

cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CH",
      "L": "Fribourg",
      "O": "system:node-proxier",
      "OU": "kriegalex",
      "ST": "Fribourg"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

}

# KUBE-SCHEDULER
{

cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CH",
      "L": "Fribourg",
      "O": "system:kube-scheduler",
      "OU": "kriegalex",
      "ST": "Fribourg"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler

}

# KUBERNETES
{

KUBERNETES_PUBLIC_ADDRESS=$(curl -4s icanhazip.com)

KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CH",
      "L": "Fribourg",
      "O": "Kubernetes",
      "OU": "kriegalex",
      "ST": "Fribourg"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

}

# SERVICE-ACCOUNT
{

cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CH",
      "L": "Fribourg",
      "O": "Kubernetes",
      "OU": "kriegalex",
      "ST": "Fribourg"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

}

for instance in kube-worker0 kube-worker1 kube-worker2; do
  internal_ip=$(openstack server show ${instance} -f json | jq -r --arg network_name "$network_id" '.addresses[$network_name][0]')
  scp -i ../.ssh/id_ecdsa \
      ca.pem ${instance}-key.pem ${instance}.pem \
      ubuntu@$internal_ip:~/
done

for instance in kube-controller0 kube-controller1 kube-controller2; do
  internal_ip=$(openstack server show ${instance} -f json | jq -r --arg network_name "$network_id" '.addresses[$network_name][0]')
  scp -i ../.ssh/id_ecdsa \
      ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
      service-account-key.pem service-account.pem \
      ubuntu@$internal_ip:~/
done