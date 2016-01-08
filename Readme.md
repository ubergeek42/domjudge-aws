# DOMjudge AWS
A set of scripts for running a DOMjudge cluster on AWS


## AWS Setup
You need to do a few things on AWS first before you can use this tool.

### IAM User
You will need to create a user with an AWS keypair(This keypair ). Go to the [IAM Console Users Tab](https://console.aws.amazon.com/iam/home#users) then create a new User. Make sure to note the `Access Key ID` and `Secret Access Key` as you'll need these later.
On the permissions tab for your newly created user, attach the following `Managed Policies`:
* AmazonEC2FullAccess
* AmazonDynamoDBFullAccess
* AmazonRoute53FullAccess
* AmazonS3FullAccess
* AmazonSESFullAccess
* AmazonSNSFullAccess
* AmazonRDSFullAccess
* IAMFullAccess

### Create an SSH KeyPair
Open the AWS console and go to [EC2 Key Pairs](https://console.aws.amazon.com/ec2/v2/home#KeyPairs).

If you have an existing public/private ssh keypair you want to click "Import Key Pair" and upload your public key. Use whatever you want for a KeyPair name, but make sure to take note of what you chose.

If you do not already have an ssh keypair, click "Create Key Pair". Enter a name for your key and then click "Create". Your browser will then automatically download the private key. Make sure you save this(maybe in ~/.ssh/keypair_name) as you will not be able to download it again.

This keypair is what you will use if you ever need to ssh into any of your cluster instances.

### Create your DOMserver and JudgeHost AMIs
With your IAM user created, it's time to create two AMIs that will be the basis for your cluster. One is for the web backends and the other is for the judgehosts. These live in a separate repository, so follow these two links and then come back here when you're done.

DOMServer - https://github.com/ubergeek42/domserver-ami  
JudgeHost - https://github.com/ubergeek42/judgehost-ami  

Make sure you take note of the AMI IDs for each of these images. If you create the images but lost the IDs you can find them by going to the [AMIs Section under EC2 in the AWS Console](https://console.aws.amazon.com/ec2/v2/home#Images).

### Create an SNS topic for notifications
During setup many alarms will be created to notify you when things are (potentially) going downhill. Things like latency alarms for the database, autoscaling actions, and various other things.
Log into the [SNS console](https://console.aws.amazon.com/sns/v2/home#/home), then choose "Create Topic". Enter a `Topic Name`, for example: "DOMjudge-Alerts". Leave the `Display Name` blank. Make note of the "Topic ARN" shown on the resulting page, as you'll need this later. It should look something like `arn:aws:sns:aws-region:000000000000:DOMjudge-Alerts`.

Next click on the "Create Subscription" button. Change `Protocol` to "Email", then enter your email address in the `Endpoint` box. Click "Create Subscription". You will receive an email from amazon asking you to confirm your subscription, click the link in the email to do so.

Create as many subscriptions as you'd like for anyone who you want to be notified of any potential issues with your cluster.

### Create an S3 Bucket to hold your DOMjudge installation archives
The web server AMI does not actually include any DOMjudge code. When the server is deployed the code is copied from an Amazon S3 bucket.

Go to the [S3 Console](https://console.aws.amazon.com/s3/home), then click on "Create Bucket". Enter a _globally unique name_, such as `AWSUSERNAME-domjudge-archives`. You also need to select the region you want to store these archives. Choose the same region you intend to run your cluster in for best results.

## Install Terraform
All of the AWS resources are managed using Terraform, so you'll need to install
it if you haven't already. It's distributed as a zip file and all the binaries
are statically linked so just extract them to somewhere on your path and you'll
be all set.

[Download Terraform Here](https://terraform.io/downloads.html)

## Install the AWS command line tools
If you didn't already, install the AWS command line tools.
```
pip install awscli
```

Also, make sure you run `aws configure` to set up your credentials and default region. You can leave the "Default output format" as None.

## Prepare the DOMjudge Webserver Components
Edit the `prepare.sh` script and set the `S3BUCKET` variable to the name of the S3 Bucket you created above. You can also change the DOMjudge repository or TAG that will be used. Leave the defaults for those if you are unsure what to do.

Run the script. It will build and install the domjudge server, apply some patches we need to run on AWS and then create a tar.gz file out of it. Then it will upload this into your S3 Bucket.
```
./prepare.sh
```

At the end of the output you should see something like the following
```
Fixing paths
Building archive
make_bucket: s3://domserver-archives/
upload: ./domserver-2016-01-08-125844.tar.gz to s3://domserver-archives/domserver-2016-01-08-125844.tar.gz
DOMserver "5.0" Built
Uploaded to S3
```

Make note of the archive file name(In this case that is `domserver-2016-01-08-125844.tar.gz`)

## Configure Terraform Globally
Copy the `terraform.tfvars.dist` file to `terraform.tfvars`. This is the global configuration file for this project.(It is intended at some point to be able to manage multiple domjudge clusters, not just one).

Fill in the various fields in the file, following the comments listed.

## Configure this DOMjudge cluster
Copy `main.tf.dist` to `main.tf`. This is your cluster specific settings. Fill in all the variables at the top paying attention to the comments in the file.

## Get terraform ready to go
Once you've edited all the configuration variables, you need to tell Terraform to prepare the submodules it needs. Simply run this command(You'll only ever need to do this step once)
```
terraform get
```

## Run Terraform
First you probably want to plan to see what terraform will do.
```
terraform plan --module-depth=1
```
This does not change anything or provision any resources, but simply shows you
what changes will be made.

If you're satisfied with these changes go ahead and run
```
terraform apply
```
Wait for it to complete. If there are any error messages you may need to re-run terraform apply. This should take around 10-30minutes depending on how quickly your ec2/rds instances boot up and become ready.
