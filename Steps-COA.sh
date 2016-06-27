#!/bin/bash

# This program takes 7 arguments in the following order
# $1 - ami image-id
# $2 - count
# $3 - instance-type
# $4 - security-group-ids
# $5 - subnet-id
# $6 - key-name
# $7 - iam-profile

declare -a ELBNAME=coa-mrp-lb
LAUNCHCONFNAME=coa-mrp-launch-config
AUTOSCALINGNAME=coa-mrp-asg
TOPICNAME=coa-notify-mrp
METRICNAME=coa-mrp-cloud-alert
PHONENUMBER=19143193344

#Step 1a: Launch the instances and provide the user-data via the install-env.sh

echo -e "\n Launching Instances"

declare -a INSTANCELIST 
INSTANCELIST=(`aws ec2 run-instances --image-id $1 --count $2 --instance-type $3 --security-group-ids $4 --subnet-id $5 --key-name $6 --associate-public-ip-address --iam-instance-profile Name=$7 --user-data file://../Environment-COA/install-env.sh --output text | grep INSTANCES | awk {' print $7'}`)

for i in {0..60}; do echo -ne '.'; sleep 1;done

#Step 1b: Listing the instances

echo -e "\n Listing Instances, filtering their instance-id, adding them to an ARRAY and sleeping 15 seconds"
for i in {0..15}; do echo -ne '.'; sleep 1;done

echo -e "\n The instance ids are \n" ${INSTANCELIST[@]}

echo -e "\n Finished launching EC2 Instances, waiting for the instances to be in running state and sleeping 60 seconds"

for i in {0..60}; do echo -ne '.'; sleep 1;done

aws ec2 wait instance-running --instance-ids ${INSTANCELIST[@]} 

#Step 2a:  Create a ELBURL variable, and create a load balancer. 
 
declare -a ELBURL

ELBURL=(`aws elb create-load-balancer --load-balancer-name $ELBNAME --listeners Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80 --subnets $5 --security-groups $4`) 

echo -e "\n Load Balancer link is \n" ${ELBURL[@]}

#Step 2b: Configure the elb configure-health-check and attach cookie stickiness policy

echo -e "\n Configuring health and cookie stickiness policies for load balancer"

aws elb configure-health-check --load-balancer-name $ELBNAME --health-check Target=HTTP:80/index.html,Interval=30,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=3

aws elb create-lb-cookie-stickiness-policy --load-balancer-name $ELBNAME --policy-name itmo544-mrp-lb-cookie-policy --cookie-expiration-period 60

aws elb set-load-balancer-policies-of-listener --load-balancer-name $ELBNAME --load-balancer-port 80 --policy-names itmo544-mrp-lb-cookie-policy

echo -e "\n Finished ELB health check and sleeping 25 seconds"
for i in {0..25}; do echo -ne '.'; sleep 1;done

#Step 2c: Register the instances with the load balancer

aws elb register-instances-with-load-balancer --load-balancer-name $ELBNAME --instances ${INSTANCELIST[@]}

echo -e "\n Finished launching ELB and registering instances, now sleeping for 25 seconds " 
for i in {0..25}; do echo -ne '.'; sleep 1;done

#Step 3a: Configure launch configuration

echo -e "\n Creating Launch Configuration"
aws autoscaling create-launch-configuration --launch-configuration-name $LAUNCHCONFNAME --iam-instance-profile $7 --user-data file://../Environment-COA/install-env.sh --key-name $6 --instance-type $3 --security-groups $4 --image-id $1

echo -e "\n Finished launching configuration and sleeping 25 seconds"
for i in {0..25}; do echo -ne '.'; sleep 1;done

#Step 3b: Configure auto scaling groups

echo -e "\n Creating Auto scaling group"
aws autoscaling create-auto-scaling-group --auto-scaling-group-name $AUTOSCALINGNAME --launch-configuration-name $LAUNCHCONFNAME --load-balancer-names $ELBNAME --health-check-type ELB --min-size 3 --max-size 6 --desired-capacity 3 --default-cooldown 600 --health-check-grace-period 120 --vpc-zone-identifier $5

echo -e "\n Finished creating auto scaling group and sleeping 25 seconds"
for i in {0..25}; do echo -ne '.'; sleep 1;done

#Step 4a: Create scale out and scale in policies

declare -a SPURL

SPURL=(`aws autoscaling put-scaling-policy --policy-name coa-mrp-scaleout-policy --auto-scaling-group-name $AUTOSCALINGNAME --scaling-adjustment 3 --adjustment-type ChangeInCapacity`)

echo -e "\n The Scale out policy ARN " ${SPURL[@]}

declare -a SPURL1

SPURL1=(`aws autoscaling put-scaling-policy --policy-name coa-mrp-scalein-policy --auto-scaling-group-name $AUTOSCALINGNAME --scaling-adjustment -3 --adjustment-type ChangeInCapacity`)

echo -e "\n The Scale in policy ARN " ${SPURL1[@]}

#Step 4b: Create an SNS topic for cloud watch metrics subscriptions

METRICARN=(`aws sns create-topic --name $METRICNAME`)
aws sns set-topic-attributes --topic-arn $METRICARN --attribute-name DisplayName --attribute-value $METRICNAME

#Step 4c: Subscribe user phone number to the topic

aws sns subscribe --topic-arn $METRICARN --protocol sms --notification-endpoint $PHONENUMBER

#Step 4d: Launch cloud metrics for the auto scaling group and sns topic

aws cloudwatch put-metric-alarm --alarm-name AddCapacity --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 60 --threshold 30 --comparison-operator GreaterThanOrEqualToThreshold --dimensions "Name=AutoScalingGroupName,Value=$AUTOSCALINGNAME" --evaluation-periods 1 --unit Percent --alarm-actions ${SPURL[@]} ${METRICARN[@]}

aws cloudwatch put-metric-alarm --alarm-name RemoveCapacity --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 60 --threshold 10 --comparison-operator LessThanOrEqualToThreshold --dimensions "Name=AutoScalingGroupName,Value=$AUTOSCALINGNAME" --evaluation-periods 1 --unit Percent --alarm-actions ${SPURL1[@]} ${METRICARN[@]}

echo -e "\n Finished creating cloud watch metrics and sleeping 25 seconds"
for i in {0..25}; do echo -ne '.'; sleep 1;done


#Step 5: Launch ELB in firefox

echo -e "\n Waiting an additional 1 minute before opening the ELB in browser"
for i in {0..60}; do echo -ne '.'; sleep 1;done

firefox $ELBURL &






 




