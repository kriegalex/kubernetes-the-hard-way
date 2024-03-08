#!/bin/bash

network_id="kube-private"
subnet_id="kube-private-subnet"
flavor="e2-standard-2"
key_name="mykey"
image_id="ubuntu-22.04-lts"
security_group="kubernetes"
volume_size="200"
public_network_id="public1"

# Specify the static IPs you want to assign to each port
controller_static_ips=("10.240.0.10" "10.240.0.11" "10.240.0.12")

# Specify the static IPs you want to assign to each port
worker_static_ips=("10.240.0.20" "10.240.0.21" "10.240.0.22")

# Create 3 network ports for controllers
for i in {0..2}
do
  port_id=$(openstack port create --network $network_id --fixed-ip subnet=$subnet_id,ip-address=${controller_static_ips[$i]} --security-group $security_group controller$i --format value -c id)
  echo "Created port $i with ID: $port_id"

  # Store the port IDs in an array
  port_ids[i]=$port_id
done

# create 3 controller instances
for i in {0..2}
do
  openstack server create --image $image_id \
                          --flavor $flavor \
                          --key-name $key_name \
                          --security-group $security_group \
                          --nic port-id=${port_ids[i]} \
                          --boot-from-volume $volume_size --wait \
                          kube-controller${i}
done

# Create 3 network ports for workers
for i in {0..2}
do
  port_id=$(openstack port create --network $network_id --fixed-ip subnet=$subnet_id,ip-address=${worker_static_ips[$i]} --security-group $security_group worker$i --format value -c id)
  echo "Created port $i with ID: $port_id"

  # Store the port IDs in an array
  port_ids[i]=$port_id
done

# create 3 worker instances
for i in {0..2}
do
  openstack server create --image $image_id \
                          --flavor $flavor \
                          --key-name $key_name \
                          --security-group $security_group \
                          --nic port-id=${port_ids[i]} \
                          --boot-from-volume $volume_size --wait \
                          kube-worker${i}
done

# create floating IP for each instance
for instance_id in $(openstack server list --format value -c ID)
do
  floating_ip=$(openstack floating ip create $public_network_id --format value -c floating_ip_address)
  echo "Created floating IP: $floating_ip"
  openstack server add floating ip $instance_id $floating_ip
  echo "$floating_ip associated to instance $instance_id"
done