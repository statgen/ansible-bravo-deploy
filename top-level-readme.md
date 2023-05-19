# Bravo Example on AWS
Provision infrastructure and deploy BRAVO applications. 

To that end, this project is partitioned into two parts.
The first provisions infrastructure on AWS on which to run the applications.
The second is an ansible script to deploy and start the application.

## Dependencies

Make sure to record the names of the keypair, bucket, and domain you'll be using.  
They are required input parameters to the terraform provisioning.

### Software
- An [AWS account](https://aws.amazon.com).  The resources will incur charges to your account.
- [AWS CLI installed](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) 
- [Terraform installed](https://learn.hashicorp.com/tutorials/terraform/install-cli) 
- [Terraform Cloud](https://cloud.hashicorp.com/products/terraform)
- AWS Credentials in Terraform Cloud [workspace variables](https://learn.hashicorp.com/tutorials/terraform/cloud-workspace-configure)
- [Ansible installed](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) 

### AWS EC2 KeyPair
Generate ssh keys to use to access the EC2 instances: 
[key-pair docs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#prepare-key-pair)

### Data in a bucket
An archive of data needs to be in place in an S3 bucket before running this project.

For running this project a subset of chr11 has been used to make a small data set.
It is available here: ftp://share.sph.umich.edu/bravo/bravo_vignette_data.tar.bz2
The provisioning and deployment expect the archive to be in a S3 bucket.

For example:
```sh
# Create bucket for holding the bravo data.  
aws s3 mb "s3://my-bravo-bucket" 

# Put data in the bucket
aws s3 cp ./bravo_vignette_data.tar.bz2 s3://my-bravo-bucket
```

### Domain name and Certificate
You'll need a domain registered on
[Route53](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/registrar.html)
and a 
[public TLS certificate](https://docs.aws.amazon.com/acm/latest/userguide/gs-acm-request-public.html) 
that covers your domain and a bravo subdomain (e.g. bravo.example.com). 
This **cert name** needs to be the domain and tld.  e.g. example.com.
The cert needs to have an additional name (SAN) that covers the subdomain.
E.g. SAN with bravo.example.com or \*.example.com

## 1. Provision Infrastrucutre on AWS
Terraform config derived from 
[this Hashicorp tutorial](https://learn.hashicorp.com/tutorials/terraform/blue-green-canary-tests-deployments)

See [Provisioning readme](provision/readme.md).

## 2. Deploy Applications
Ansible playbook to install, configure, load data, and run BRAVO's components.

See [Deployment readme](deploy/readme.md).

## Use
Manual run of infrastructure provisioning and deployment of applications.

### Configure Terraform Variables
Use terraform variables stored in workspace on terraform cloud.
Or provide a terraform variables file with the name of the keypair, bucket, and domain name you'll be using.

note: the app deployment will wire the application server to the bravo subdomain (e.g. bravo.example.com)

### Run Terraform and Ansible
First use terraform to provision the VMs and infrastructure.
Subsequently use ansible to deploy the applications.

```sh 
# Move into provisioning directory
cd provision

# Run terraform
terraform apply

# (Optional) print convenient ssh commands for bastion or app server. 
./print_ssh_cmd.sh

# Move into deployment directory
cd ../deploy

# Create Ansible config from terraform cloud plan output
./make_ansible_support_files.sh

# Run ansible
ansible-playbook --ssh-common-args='-F inv/deploy-ssh-config' -i 'inv/deploy-inventory' playbook.yml
```

## Improvements to be made

- Make it as easy as possible for someone to deploy with as few commands as possible. 
    - Link to terraform installer
    - Link to ansible installers.
- Make as many choices for the end user as you possibly can.
    - Using default values in the variables
    - Handling cases to minimize requirements
        - Make domain & cert optional
        - Make S3 data bucket optional
    - Allow specifying a pre-existing VPC
- List the variables and a description of what they do like Terraform modules
- Make clear how to get the bravo\_vignette data.
- Consider makeing and publishing a pre-built AMI or container to avoid Anisble install.
- Use Ubuntu image for bastion as well for uniformity.

