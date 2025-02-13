#!/bin/bash

node_name="as-use1-eng01-node"

generate_random_string() {
  local length=$1
  openssl rand -hex "$length"
}
prefix_length=6
random_prefix=$(generate_random_string "$prefix_length")

az=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
region=${az%%?}
instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

aws ec2 create-tags --resources $instance_id --region $region --tags \
Key=Name,Value=${node_name}-${random_prefix}
