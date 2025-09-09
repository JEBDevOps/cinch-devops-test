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

# Terraform Deployment

This project can also be deployed using Terraform. The Terraform configuration will create a similar environment to the CloudFormation templates, but uses Tailscale for VPN access instead of a bastion host.

## Tailscale Setup

To deploy the infrastructure with Tailscale, you will need to perform a few manual setup steps first.

### 1. Generate a Tailscale Auth Key

The Terraform configuration requires a Tailscale authentication key to automatically register the new subnet router instance.

1.  **Log in** to your Tailscale admin console at [https://login.tailscale.com/admin](https://login.tailscale.com/admin).
2.  Navigate to the **Settings** page, then select **Auth keys**.
3.  Click the **Generate auth key...** button.
4.  Configure the key:
    *   **Description:** Give it a clear description, like `Terraform AWS Subnet Router`.
    *   **Reusable:** Select this option.
    *   **Ephemeral:** Do not select this.
    *   **Pre-authorized:** It's recommended to select this to avoid manually approving the new machine.
    *   **Tags:** You can optionally add a tag, for example `tag:subnet-router`.
5.  Click **Generate key**.
6.  **Copy the generated key** (it will start with `tskey-auth-`). You will only be shown this key once, so make sure to copy it immediately.

### 2. Create a `terraform.tfvars` file

In the `terraform` directory, create a new file named `terraform.tfvars` and add the auth key you just generated:

```
tailscale_auth_key = "tskey-auth-..."
```

You will also need to provide your AWS Account ID in this file:

```
aws_account_id = "123456789012"
```

### 3. Deploy with Terraform

Once the `terraform.tfvars` file is created, you can deploy the infrastructure:

```shell
cd terraform
terraform init
terraform apply
```

### 4. Approve Subnet Routes

After `terraform apply` is complete, you need to enable the subnet routing in the Tailscale admin console:

1.  Go to the **Machines** page in your Tailscale admin console.
2.  Find the new `tf-subnet-router` machine.
3.  Click the three-dot menu (`...`) next to it and select **Edit route settings...**.
4.  Approve the subnet route (e.g., `10.0.2.0/24`).

Once the route is approved, you will be able to access the private subnet resources from any device on your Tailscale network.
