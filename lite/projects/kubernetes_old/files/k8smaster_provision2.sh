#!/usr/bin/env bash
# Copyright (c) 2016, Department for Business, Innovation and Skills
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the <organization> nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL BIS BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Provision a Kubernetes master on RHEL7 or RHEL Atomic part 2
# https://access.redhat.com/documentation/
#+en/red-hat-enterprise-linux-atomic-host/version-7/getting-started-guide/

set -o nounset
set -o errexit
set -o pipefail

exec 1> >( sed "s/^/$(date '+[%F %T]'): /" | tee -a /tmp/provision.log) 2>&1

MNAME="`hostname`"
MASTER_IP="`getent ahosts $MNAME | tail -n1 | awk '{print$1}'`"
NAMEDSRV="10.100.100.3"
SKYDNSIP="10.254.1.1"
DOMNAME="lite.local"

# Edit the /etc/kubernetes/kublet config
sed -ie 's|KUBELET_ADDRESS=".*"|KUBELET_ADDRESS="--address=0.0.0.0"|' \
  /etc/kubernetes/kubelet
sed -ie "s|KUBELET_HOSTNAME=\".*\"|KUBELET_HOSTNAME=\"--hostname-override=${MNAME}\"|" \
  /etc/kubernetes/kubelet
sed -ie "s|KUBELET_API_SERVER=\".*\"|KUBELET_API_SERVER=\"--api-servers=http://${MNAME}:8080\"|" \
  /etc/kubernetes/kubelet

KPIC="--pod-infra-container-image=registry.access.redhat.com/rhel7/pod-infrastructure:latest"

sed -ie "s|KUBELET_POD_INFRA_CONTAINER=\".*\"|KUBELET_POD_INFRA_CONTAINER=\"$KPIC\"|" \
  /etc/kubernetes/kubelet

KUBELET_ARGS="--register-node=true --config=/etc/kubernetes/manifests"
KUBELET_ARGS="$KUBELET_ARGS --resolv-conf=''"
KUBELET_ARGS="$KUBELET_ARGS --cluster-dns=${SKYDNSIP} --cluster-domain=${DOMNAME}"

sed -ie "s|KUBELET_ARGS=\".*\"|KUBELET_ARGS=\"${KUBELET_ARGS}\"|" \
  /etc/kubernetes/kubelet

# Create the manifests directory
mkdir -p /etc/kubernetes/manifests

# Create manifest files
cat - > /etc/kubernetes/manifests/apiserver.pod.json << __EOF__
{
  "kind": "Pod",
  "apiVersion": "v1",
  "metadata": {
  "name": "kube-apiserver"
},
  "spec": {
    "hostNetwork": true,
    "containers": [
      {
        "name": "kube-apiserver",
        "image": "rhel7/kubernetes-apiserver",
        "command": [
          "/usr/bin/kube-apiserver",
          "--v=0",
          "--insecure-bind-address=0.0.0.0",
          "--etcd_servers=http://${MASTER_IP}:2379",
          "--service-cluster-ip-range=10.254.0.0/16",
          "--admission_control=NamespaceLifecycle,NamespaceExists,LimitRanger,SecurityContextDeny,ResourceQuota"
        ],
        "ports": [
          {
            "name": "https",
            "hostPort": 443,
            "containerPort": 443
          },
          {
            "name": "local",
            "hostPort": 8080,
            "containerPort": 8080
          }
        ],
        "volumeMounts": [
          {
            "name": "etcssl",
            "mountPath": "/etc/ssl",
            "readOnly": true
          },
          {
            "name": "config",
            "mountPath": "/etc/kubernetes",
            "readOnly": true
          }
        ],
        "livenessProbe": {
          "httpGet": {
            "path": "/healthz",
            "port": 8080
          },
          "initialDelaySeconds": 15,
          "timeoutSeconds": 15
        }
      }
    ],
    "volumes": [
      {
        "name": "etcssl",
        "hostPath": {
          "path": "/etc/ssl"
        }
      },
      {
        "name": "config",
        "hostPath": {
          "path": "/etc/kubernetes"
        }
      }
    ]
  }
}
__EOF__

cat - > /etc/kubernetes/manifests/controller-manager.pod.json << __EOF__
{
  "kind": "Pod",
  "apiVersion": "v1",
  "metadata": {
    "name": "kube-controller-manager"
  },
  "spec": {
    "hostNetwork": true,
    "containers": [
      {
        "name": "kube-controller-manager",
        "image": "rhel7/kubernetes-controller-mgr",
        "volumeMounts": [
          {
            "name": "etcssl",
            "mountPath": "/etc/ssl",
            "readOnly": true
          },
          {
            "name": "config",
            "mountPath": "/etc/kubernetes",
            "readOnly": true
          }
        ],
        "livenessProbe": {
          "httpGet": {
            "path": "/healthz",
            "port": 10252
          },
           "initialDelaySeconds": 15,
           "timeoutSeconds": 15
         }
        }
      ],
      "volumes": [
        {
          "name": "etcssl",
          "hostPath": {
            "path": "/etc/ssl"
          }
        },
        {
        "name": "config",
        "hostPath": {
          "path": "/etc/kubernetes"
        }
      }
    ]
  }
}
__EOF__

cat - > /etc/kubernetes/manifests/scheduler.pod.json << __EOF__
{
  "kind": "Pod",
  "apiVersion": "v1",
  "metadata": {
    "name": "kube-scheduler"
  },
  "spec": {
    "hostNetwork": true,
    "containers": [
      {
        "name": "kube-scheduler",
        "image": "rhel7/kubernetes-scheduler",
        "volumeMounts": [
          {
            "name": "config",
            "mountPath": "/etc/kubernetes",
            "readOnly": true
          }
        ],
        "livenessProbe": {
          "httpGet": {
            "path": "/healthz",
            "port": 10251
          },
          "initialDelaySeconds": 15,
          "timeoutSeconds": 15
        }
      }
    ],
    "volumes": [
      {
        "name": "config",
        "hostPath": {
          "path": "/etc/kubernetes"
        }
      }
    ]
  }
}
__EOF__

# Setup SkyDNS
cat - > /etc/kubernetes/manifests/kubedns-rc.yaml << __EOF__
apiVersion: v1
kind: ReplicationController
metadata:
  name: kube-dns-v11
  namespace: default
  labels:
    k8s-app: kube-dns
    version: v11
    kubernetes.io/cluster-service: "true"
spec:
  replicas: 1
  selector:
    k8s-app: kube-dns
    version: v11
  template:
    metadata:
      labels:
        k8s-app: kube-dns
        version: v11
        kubernetes.io/cluster-service: "true"
    spec:
      containers:
        - name: etcd
          image: gcr.io/google_containers/etcd-amd64:2.2.1
          command:
          - /usr/local/bin/etcd
          - -data-dir
          - /var/etcd/data
          - -listen-client-urls
          - http://127.0.0.1:2379,http://127.0.0.1:4001
          - -advertise-client-urls
          - http://127.0.0.1:2379,http://127.0.0.1:4001
          - -initial-cluster-token
          - skydns-etcd
        - name: kube2sky
          image: gcr.io/google_containers/kube2sky-amd64:1.15
          args:
          - --domain=${DOMNAME}
          - --kube-master-url=http://${MASTER_IP}:8080
        - name: skydns
          image: gcr.io/google_containers/skydns:2015-10-13-8c72f8c
          env:
          - name: SKYDNS_NAMESERVERS
            value: ${NAMEDSRV}:53
          args:
          # command = "/skydns"
          - -domain=${DOMNAME}.
          - -machines=http://127.0.0.1:4001
          - -addr=0.0.0.0:53
          ports:
            - containerPort: 53
              name: dns
              protocol: UDP
            - containerPort: 53
              name: dns-tcp
              protocol: TCP
      dnsPolicy: Default
__EOF__

cat - > /etc/kubernetes/manifests/kubedns-svc.yaml << __EOF__
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: default
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    kubernetes.io/name: "KubeDNS"
spec:
  selector:
    k8s-app: kube-dns
  clusterIP: ${SKYDNSIP}
  ports:
  - name: dns
    port: 53
    protocol: UDP
  - name: dns-tcp
    port: 53
    protocol: TCP
__EOF__

# Stop and configure kubernetes services
for SERVICES in kube-apiserver kube-controller-manager kube-scheduler
do
  systemctl stop $SERVICES
  systemctl disable $SERVICES
done
systemctl restart etcd ; systemctl enable etcd

# Wait for Docker to complete start up
echo Waiting for docker to start. This may take a couple minutes.
DRNG="inactive"
until [ "$DRNG" = "active" ]
do
  sleep 5
  DRNG=`systemctl is-active docker || /bin/true`
done

# Get kubernetes master containers
echo Fetching Kubernetes master containers
docker pull registry.access.redhat.com/rhel7/kubernetes-apiserver
docker pull registry.access.redhat.com/rhel7/kubernetes-controller-mgr
docker pull registry.access.redhat.com/rhel7/kubernetes-scheduler

# Start the kubelet to launch the kubernetes service containers
systemctl enable kube-proxy kubelet
systemctl start kube-proxy kubelet

# Set the default cluster config
su -l vagrant << __EOF__
kubectl config set-cluster default-cluster --server=http://${MNAME}:8080
kubectl config set-context default-system --cluster=default-cluster
kubectl config use-context default-system
__EOF__