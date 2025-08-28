#!/bin/bash

# run this at ./envs/dev : cd ./envs/dev/
aws ec2 describe-instances --instance-ids $(terraform output -raw ec2_instance_id) --query 'Reservations[*].Instances[*].{Instance:InstanceId,State:State.Name,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress}' --output table