# How to use the AWS terraform setup.

## Files in the archive

* `aws.tfvars.example`

  An example file demonstrating the variables the user can (and in
  some cases 'has to') modify to get a proper setup.

* `aws.tf`

  The main terraform configuration, containing the fixed parts of the
  setup.

* `hcf-aws.tf.json`

  The cluster definition, generated from HCF's `roles-manifest.yml`.

* `container-host-files`

  Scripts and configuration files uploaded into the µcloud to support
  its provisioning.

## Usage

* Copy `aws.tfvars.example` to `aws.tfvars` and then edit the
  configuration to suit the environment (keys, etc). See the
  comments in the file itself.

  Note: If a filename other than `aws.tfvars` is chosen then all
  instances of `aws.tfvars` in the commands below must be replaced
  with the actual name of the file.

* Ensure that the following variables for access to Amazon AWS in
  general are defined in the local environment, with the information
  of the user doing the access:

```bash
export AWS_ACCESS_KEY_ID="..." 
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="us-west-2"
```

  This information can be extracted from AWS when the user in question
  is created.

* Run

```bash
   terraform plan -var-file=aws.tfvars .
```

  This checks that everything is ok. Terraform should __not__ ask for
  the value of any variable.

* Run

```bash
   terraform apply -var-file=aws.tfvars .
```

  to set up the specified configration.


# Troublespots

## Certificates and other secrets

To use the development secrets (instead of supplying your own in
`aws.tfvars`), regenerate `hcf-aws.tf.json` with them built in:

```bash
  make aws ENV_DIR=$PWD/bin
```

## Terraform

If you see

```
  Errors:
    * provider.aws: : invalid or unknown key: insecure
```

upgrade your installation of ```terraform``` to version 0.6.12 or
higher.

## ACL destruction

TF claims that it is sucessfully destroying the ACL.

It is not.

The ACL must be destroyed manually.

See next section for information about the AWS web console.

## AWS Web console

The important sections are EC2 and VPC.

   * (https://us-west-2.console.aws.amazon.com/vpc/home?region=us-west-2#acls:)[VPC]

      * Your VPC
      * Subnets
      * Internet Gateway
      * Network ACLs

   * (https://us-west-2.console.aws.amazon.com/ec2/v2/home?region=us-west-2#Instances:sort=tag:Name)[EC2]

      *	Instances
      *	Security Groups
      *	Key Pairs

## Docker Trusted Registry

The account information (name, password) in the provided example
.tfvars file is __fixed__. Do __not change__ that part.