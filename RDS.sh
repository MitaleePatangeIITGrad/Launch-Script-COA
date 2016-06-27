#!/bin/bash

DBSUBNETNAME=coa-mrp-subnet
DBINSTANCEIDENTIFIER=coa-mysql-wordpress-db
DBUSERNAME=controller
DBPASSWORD=ilovebunnies
DBNAME=wordpressdb
SUBNET1=subnet-14fcce3f
SUBNET2=subnet-1e5e7547

#Step 5a: Create a subnet group

echo -e "\n Creating subnet group for db instance"

aws rds create-db-subnet-group --db-subnet-group-name $DBSUBNETNAME --db-subnet-group-description MiniProject1 --subnet-ids  $SUBNET1 $SUBNET2

#Step 5b: Launch RDS mysql database

echo -e "\n Creating db instance"
aws rds create-db-instance --db-instance-identifier $DBINSTANCEIDENTIFIER --allocated-storage 20 --db-instance-class db.t1.micro --engine mysql --master-username $DBUSERNAME --master-user-password $DBPASSWORD --engine-version 5.6.23 --license-model general-public-license --no-multi-az --storage-type standard --publicly-accessible --availability-zone us-east-1a --db-name $DBNAME --port 3306  --auto-minor-version-upgrade --preferred-maintenance-window mon:00:00-mon:01:30 --vpc-security-group-ids $1 --db-subnet-group-name $DBSUBNETNAME

#Step 5c: Wait for the instance to be available

echo -e "\n Waiting after launching RDS mysql database to make it available for 10 minutes"
for i in {0..600}; do echo -ne '.'; sleep 1;done

aws rds wait db-instance-available --db-instance-identifier $DBINSTANCEIDENTIFIER

#Step 6: Describe db instances

declare -a DBINSTANCEARR

DBINSTANCEARR=(`aws rds describe-db-instances --output text | grep ENDPOINT | awk {' print $2'}`)

echo ${DBINSTANCEARR[@]}