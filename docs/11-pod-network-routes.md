# Provisioning Pod Network Routes

Pods scheduled to a node receive an IP address from the node's Pod CIDR range. At this point pods can not communicate with other pods running on different nodes due to missing network [routes](https://cloud.google.com/compute/docs/vpc/routes).

In this lab you will create a route for each worker node that maps the node's Pod CIDR range to the node's internal IP address.

> There are [other ways](https://kubernetes.io/docs/concepts/cluster-administration/networking/#how-to-achieve-this) to implement the Kubernetes networking model.

## The Routing Table

In this section you will gather the information required to create routes in the `kubernetes-the-hard-way` VPC network.

Print the internal IP address and Pod CIDR range for each worker instance:

```
for instance in kube-worker0 kube-worker1 kube-worker2; do
  openstack server show ${instance} -f json | \
    jq -r --arg network_name kubernetes-private '.addresses[$network_name][0],.properties."pod-cidr"'
done
```

> output

```
10.240.0.20 
10.200.0.0/24
10.240.0.21 
10.200.1.0/24
10.240.0.22 
10.200.2.0/24
```

## Routes

List the routers to double check the name we used in [chapter 03](03-compute-resources.md):

```
openstack router list
```

Create network routes for each worker instance:

```
for i in 0 1 2; do
  openstack router add route --route destination=10.200.${i}.0/24,gateway=10.240.0.2${i} kubernetes-router
done
```

List the routes in the `kubernetes-the-hard-way` VPC network:

```
openstack router show kubernetes-router -c routes
```

> output

```
+--------+----------------------------------------------------+
| Field  | Value                                              |
+--------+----------------------------------------------------+
| routes | destination='10.200.0.0/24', gateway='10.240.0.20' |
|        | destination='10.200.1.0/24', gateway='10.240.0.21' |
|        | destination='10.200.2.0/24', gateway='10.240.0.22' |
+--------+----------------------------------------------------+
```

Next: [Deploying the DNS Cluster Add-on](12-dns-addon.md)
