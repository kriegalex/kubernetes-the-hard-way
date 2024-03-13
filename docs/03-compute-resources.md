# Provisioning Compute Resources

Kubernetes requires a collection of servers to host its control plane and the worker nodes that run containers. In this lab, you will provision the necessary compute resources for a secure and highly available Kubernetes cluster using OpenStack.

## Networking

The Kubernetes [networking model](https://kubernetes.io/docs/concepts/cluster-administration/networking/#kubernetes-model) assumes a flat network in which containers and nodes can communicate with each other. In cases where this is not desired [network policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) can limit how groups of containers are allowed to communicate with each other and external network endpoints.

> Setting up network policies is out of scope for this tutorial.

This tutorial assumes that you are in a homelab setup. In this case, the local network you have available is a network behind your ISP router, or some router, that needs to be NATed to access the internet.

### Public Network

This network is your regular homelab network, that has access to internet, but behind a router (NAT). Floating IPs will come from that network, since we assume we don't have real IPv4 public IPs, like a cloud provider.

```
openstack network create --external --provider-physical-network physnet1 --provider-network-type flat kubernetes-public
openstack subnet create --no-dhcp --ip-version 4 --allocation-pool "start=10.0.0.20,end=10.0.0.99" --network kubernetes-public \
        --subnet-range "10.0.0.0/24" --gateway "10.0.0.1" kubernetes-external
```

### Router

We set up a router that will bind the public and private networks

```
openstack router create kubernetes-router
openstack router set --external-gateway kubernetes-public kubernetes-router
```

### Private Network

You'll set up a dedicated network within OpenStack to host your Kubernetes cluster, ensuring isolation and control over network resources.

Create a network and subnet for your Kubernetes cluster:

```
openstack network create kubernetes-private
```

Create a subnet within the kubernetes-private network with an appropriate CIDR:

```
openstack subnet create --network kubernetes-private --subnet-range 10.240.0.0/24 kubernetes-internal
```

This subnet provides a private IP address for each node in the Kubernetes cluster.

> The `10.240.0.0/24` IP address range can host up to 254 compute instances.

Don't forget to add it to your Openstack router:

```
openstack router add subnet kubernetes-router kubernetes-internal
```

### Firewall Rules

First, create a security group for internal communication:

```
openstack security group create kubernetes-allow-internal
```

Then, add rules to allow TCP, UDP, and ICMP within your specified IP ranges:

```
openstack security group rule create --proto tcp --dst-port 1:65535 --remote-ip 10.240.0.0/24 kubernetes-allow-internal
openstack security group rule create --proto udp --dst-port 1:65535 --remote-ip 10.240.0.0/24 kubernetes-allow-internal
openstack security group rule create --proto icmp --remote-ip 10.240.0.0/24 kubernetes-allow-internal

openstack security group rule create --proto tcp --dst-port 1:65535 --remote-ip 10.200.0.0/16 kubernetes-allow-internal
openstack security group rule create --proto udp --dst-port 1:65535 --remote-ip 10.200.0.0/16 kubernetes-allow-internal
openstack security group rule create --proto icmp --remote-ip 10.200.0.0/16 kubernetes-allow-internal
```

Next, create a security group for external access, allowing SSH, ICMP, and HTTPS:

```
openstack security group create kubernetes-allow-external
```

Add the rules for external access:

```
openstack security group rule create --proto tcp --dst-port 22 kubernetes-allow-external
openstack security group rule create --proto tcp --dst-port 6443 kubernetes-allow-external
openstack security group rule create --proto icmp kubernetes-allow-external
```

> An [external load balancer](https://cloud.google.com/compute/docs/load-balancing/network/) will be used to expose the Kubernetes API Servers to remote clients.

List the firewall rules in the `kubernetes-the-hard-way` network:

```
openstack security group rule list kubernetes-allow-internal
openstack security group rule list kubernetes-allow-external
```

> output example

```
+--------------------------------------+-------------+-----------+-----------+------------+-----------+--------------------------------------+----------------------+
| ID                                   | IP Protocol | Ethertype | IP Range  | Port Range | Direction | Remote Security Group                | Remote Address Group |
+--------------------------------------+-------------+-----------+-----------+------------+-----------+--------------------------------------+----------------------+
| ac73ba0e-a0a5-4911-b0d0-8f4a2cd65eea | None        | IPv4      | 0.0.0.0/0 |            | egress    | None                                 | None                 |
| cde56aaf-12fe-4638-9abc-eea6cc8c9118 | None        | IPv6      | ::/0      |            | egress    | None                                 | None                 |
| e8d367fe-38ed-46df-8f24-0ab6983e05b6 | tcp         | IPv4      | 0.0.0.0/0 | 22:22      | ingress   | None                                 | None                 |
| f6af2020-47fb-4ee2-8d72-f0f18eae3c88 | tcp         | IPv4      | 0.0.0.0/0 | 6443:6443  | ingress   | None                                 | None                 |
+--------------------------------------+-------------+-----------+-----------+------------+-----------+--------------------------------------+----------------------+
```

### Kubernetes Public IP Address

Allocate a static IP address that will be attached to the external load balancer fronting the Kubernetes API Servers:

```
openstack floating ip create <public-network>
```

Verify the static IP address:

```
openstack floating ip list
```

> output

```
+--------------------------------------+---------------------+------------------+------+--------------------------------------+----------------------------------+
| ID                                   | Floating IP Address | Fixed IP Address | Port | Floating Network                     | Project                          |
+--------------------------------------+---------------------+------------------+------+--------------------------------------+----------------------------------+
| 2fe07d4a-bd01-4bc3-a9a4-da9adc9f2f7a | 10.0.0.77           | None             | None | 86961c23-fa71-46d1-b073-b1dc86b3495b | 7213815f097d4c838f6663d3df9117fd |
+--------------------------------------+---------------------+------------------+------+--------------------------------------+----------------------------------+
```

## Compute Instances

The compute instances in this lab will be provisioned using [Ubuntu Server](https://www.ubuntu.com/server) 20.04, which has good support for the [containerd container runtime](https://github.com/containerd/containerd). Each compute instance will be provisioned with a fixed private IP address to simplify the Kubernetes bootstrapping process.

### Ubuntu image

Make sure to download the correct [cloud image](https://cloud-images.ubuntu.com) and have it ready in the local directory. Example:

```
curl --fail -L -o ./jammy-server-cloudimg-amd64.img https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
```

In this example, we will use the [Jammy](https://releases.ubuntu.com/jammy) release of Ubuntu server (22.04) in a QCOW2 format:

```
openstack image create --disk-format qcow2 --container-format bare --public --property os_type=linux --file ./jammy-server-cloudimg-amd64.img ubuntu-22.04-lts
```

### Configuring SSH Access

We need to create a key locally and set it up in Openstack:

```
ssh-keygen -t ecdsa -N '' -f ~/.ssh/id_ecdsa
```

```
openstack keypair create --public-key ~/.ssh/id_ecdsa.pub mykey
```

### Configuring flavors

We will use a flavor named "e2-standard-2", copied from Google Cloud flavors. It has 2vCPUs and 8GB of RAM, as well as 200GB of disk space.

```
openstack flavor create --ram 8192 --disk 200 --vcpus 2 e2-standard-2
```

### Kubernetes Controllers

Create three compute instances which will host the Kubernetes control plane:

First the static IPs, then the instances:

```
for i in {0..2}
do
  port_id=$(openstack port create --network kubernetes-private --fixed-ip subnet=kubernetes-internal,ip-address=10.240.0.1$i \
                                  --security-group kubernetes-allow-external \
                                  --security-group kubernetes-allow-internal \
                                  controller$i --format value -c id)
  openstack server create --image "ubuntu-22.04-lts" \
                          --flavor "e2-standard-2" \
                          --key-name "mykey" \
                          --security-group kubernetes-allow-external \
                          --security-group kubernetes-allow-internal \
                          --nic port-id=${port_id} \
                          --boot-from-volume 200 --wait \
                          kube-controller${i}
done
```

### Kubernetes Workers

Each worker instance requires a pod subnet allocation from the Kubernetes cluster CIDR range. The pod subnet allocation will be used to configure container networking in a later exercise. The `pod-cidr` instance metadata will be used to expose pod subnet allocations to compute instances at runtime.

> The Kubernetes cluster CIDR range is defined by the Controller Manager's `--cluster-cidr` flag. In this tutorial the cluster CIDR range will be set to `10.200.0.0/16`, which supports 254 subnets.

Create three compute instances which will host the Kubernetes worker nodes:

First the static IPs, then the instances:

```
for i in {0..2}
do
  port_id=$(openstack port create --network kubernetes-private --fixed-ip subnet=kubernetes-internal,ip-address=10.240.0.2$i \
                                  --security-group kubernetes-allow-external \
                                  --security-group kubernetes-allow-internal \
                                  worker$i --format value -c id)
  openstack server create --image "ubuntu-22.04-lts" \
                          --flavor "e2-standard-2" \
                          --key-name "mykey" \
                          --security-group kubernetes-allow-external \
                          --security-group kubernetes-allow-internal \
                          --nic port-id=${port_id} \
                          --boot-from-volume 200 --wait \
                          --property pod-cidr="10.200.${i}.0/24" \
                          kube-worker${i}
done
```

### Verification

List the compute instances in your default compute zone:

```
openstack server list
```

> output

```
+--------------------------------------+------------------+--------+--------------------------------+--------------------------+---------------+
| ID                                   | Name             | Status | Networks                       | Image                    | Flavor        |
+--------------------------------------+------------------+--------+--------------------------------+--------------------------+---------------+
| f949547d-c6ef-45cc-b3c6-0b61e8daff26 | kube-worker2     | ACTIVE | kubernetes-private=10.240.0.22 | N/A (booted from volume) | e2-standard-2 |
| 7098b5c2-d326-41f7-9540-a8fdc3f77f05 | kube-worker1     | ACTIVE | kubernetes-private=10.240.0.21 | N/A (booted from volume) | e2-standard-2 |
| 0e33ed13-a20d-447e-9301-cf35acffc5a1 | kube-worker0     | ACTIVE | kubernetes-private=10.240.0.20 | N/A (booted from volume) | e2-standard-2 |
| 13849415-c19a-4aab-b25f-7860a6158e59 | kube-controller2 | ACTIVE | kubernetes-private=10.240.0.12 | N/A (booted from volume) | e2-standard-2 |
| 181f936a-97ac-40d7-b14b-cc3ad25143ec | kube-controller1 | ACTIVE | kubernetes-private=10.240.0.11 | N/A (booted from volume) | e2-standard-2 |
| 565d70ea-fd60-45ef-bab9-8ddfd7e1f2f0 | kube-controller0 | ACTIVE | kubernetes-private=10.240.0.10 | N/A (booted from volume) | e2-standard-2 |
+--------------------------------------+------------------+--------+--------------------------------+--------------------------+---------------+
```

Next: [Provisioning a CA and Generating TLS Certificates](04-certificate-authority.md)
