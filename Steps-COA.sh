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
DBSUBNETNAME=coa-mrp-subnet
DBINSTANCEIDENTIFIER=coa-mysql-wordpress-db
DBUSERNAME=controller
DBPASSWORD=ilovebunnies
DBNAME=wordpressdb
SUBNET1=subnet-14fcce3f
SUBNET2=subnet-1e5e7547
TOPICNAME=coa-notify-mrp
METRICNAME=coa-cloud-alert-mrp
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

echo -e "All Done"






 




