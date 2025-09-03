# cinch-devops-test
Test given to DevOps applicant by Cinch


# Prerequisites


## Setting Up AWS Identity Center

- Enable Identity Center
- Create Group
- Create Permission Sets
  - No need to make a custom Permission Set for now. The default PowerUserPermissions is fine.
- AWS Accounts
  - Inside AWS Accounts, we can assign Users/Groups to an AWS Account that the Root account manages.
  - We will also be asked what Permission Sets we will assign for each of the User or Group we selected
- Create User
  - When the user is created the username and password will be generated. Give that to the user.
- User Login
  - when a user logs in to the Access Portal, they will see the accounts and applications they are allowed to access
  - they will also find instructions on how to access the AWS Console and how to authenticate using AWS CLI


## SSH Key 

Create an SSH key that we will be using for this test

```shell
aws ec2 create-key-pair --region ap-southeast-1 --key-name cinch-test-key --query 'KeyMaterial' --output text > ~/.ssh/cinch-test-key.pem
```

Set the pem file's permission

```shell
chmod 400 ~/.ssh/cinch-test-key.pem
```


# Running the CloudFormation Files


## Create the Base Network

```shell
aws cloudformation deploy --stack-name net-base --template-file network.yaml --capabilities CAPABILITY_NAMED_IAM --parameter-overrides AvailabilityZone=ap-southeast-1a --no-execute-changeset
```

## Create the Bastion

```shell
aws cloudformation deploy --stack-name bastion-host --template-file bastion.yaml --parameter-overrides NetworkStackName=net-base KeyName=cinch-test-key AllowedSshCidr=<IP_HERE>/32 --no-execute-changeset
```

## Create the S3 Bucket

```shell
aws cloudformation deploy --stack-name s3-stack --template-file s3.yaml --parameter-overrides BucketName=cinch-test-logs --no-execute-changeset
```

## Create the App Instance

```shell
aws cloudformation deploy --stack-name app-demo --template-file app.yaml --capabilities CAPABILITY_NAMED_IAM --no-execute-changeset
```



# Checking

## Bastiion

To check the bastion server, first get the Bastion's Public IP, through AWS Console or through the following command:

```shell
aws ec2 describe-instances --filters "Name=tag:Name,Values=bastion-host-bastion" --query "Reservations[].Instances[].PublicIpAddress" --output text
```

```shell
ssh -i ~/.ssh/cinch-test-key.pem ec2-user@<BastionPublicIp>
```

## S3 Bucket

Checking that versioning is working

```shell
BUCKET=$(aws cloudformation list-exports --query "Exports[?Name=='s3-stack:LogsBucketName'].Value | [0]" --output text)

echo "first" > log.txt
aws s3 cp log.txt s3://$BUCKET/app/log.txt

echo "second" > log.txt
aws s3 cp log.txt s3://$BUCKET/app/log.txt

aws s3api list-object-versions --bucket "$BUCKET" --prefix app/log.txt --query 'Versions[].{VersionId:VersionId,IsLatest:IsLatest,Size:Size,LastModified:LastModified}'
```

CHecking that public access is blocked

```shell
aws s3api put-object-acl --bucket "$BUCKET" --key app/log.txt --acl public-read
# Expect an error like: AccessControlListNotSupported or AccessDenied due to PAB configuration
```


## App Instance

### SSH Key

Before we can access the App Instance from the Bastion through ssh, we have to make a `pem` file from the SSH Key that we made earlier.

```shell
sudo vim ~/.ssh/cinch-test-key.pem
```

Inside that file, paste the data from the downloaded file from before.

Then set the file owner and permissions:

```shell
sudo chown ec2-user:ec2-user ~/.ssh/cinch-test-key.pem
sudo chmod 600 ~/.ssh/cinch-test-key.pem
```

### Get Private IP of App Instance

First get the Private IP of the App Instance

```shell
aws ec2 describe-instances --filters "Name=tag:Name,Values=app-demo-app" --query "Reservations[].Instances[].PrivateIpAddress" --output text
```

Then connect to the App Instance through the Bastion Host:

```shell
ssh -i ~/.ssh/cinch-test-key.pem ec2-user@<AppPrivateIp>
```

## Checking Docker test app

Inside Bastion

```shell
curl -s http://<APP_PRIVATE_IP> | head
```

Inside App Instance

```shell
curl -s http://localhost | head
```

### Better Approach

A better approach is to have ssh forward our commands directly to the App instance through the bastion host

This can be set inside our device's `~/.ssh/config` file.

```text
Host bastion
  HostName <BastionPublicIp>
  User ec2-user
  IdentityFile ~/.ssh/cinch-test-key.pem

Host app-ec2
  HostName <PrivateInstancePrivateIp>
  User ec2-user
  ProxyJump bastion
```

Once this is set, we can directly SSH to the App Instance within our Private Subnet

```shell
ssh app-ec2
```


# Notes

```shell
aws cloudformation delete-stack --stack-name <STACK_NAME>
aws cloudformation wait stack-delete-complete --stack-name <STACK_NAME>
```


# Teardown and Cleanup

## Delete App

```shell
aws cloudformation delete-stack --stack-name app-demo

aws cloudformation wait stack-delete-complete --stack-name app-demo
```

## Delete S3

```shell
aws cloudformation delete-stack --stack-name s3-stack

aws cloudformation wait stack-delete-complete --stack-name s3-stack
```

## Delete Bastion

```shell
aws cloudformation delete-stack --stack-name bastion-host

aws cloudformation wait stack-delete-complete --stack-name bastion-host
```

## Delete Net Base

```shell
aws cloudformation delete-stack --stack-name net-base

aws cloudformation wait stack-delete-complete --stack-name net-base
```
