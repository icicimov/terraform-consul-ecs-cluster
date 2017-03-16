## AWS ECS Cluster

This is a `terraform` repository for ECS provisioning in AWS. It's been developed and tested with Terraform version `0.8.7`, future releases might introduce some incompatibilities that might need addressing.

We need to get familiar with the following AWS terms before we start:

* ECS Instance CLuster - Cluster of EC2 instances the containers will be running on
* ECS Service - Logical group of containers running the same micro service(s)
* ECS Task - Container micro service (application) definition
* ALB - Application Load Balancer, makes routing decisions at the application layer (HTTP/HTTPS), supports path-based routing, and can route requests to one or more ports on each container instance in our cluster. It also supports dynamic host port mapping, meaning we can run multiple instances of the same container on different host ephemeral ports, and HTTP/2 support is already included.

Features provided by the setup:

* Creates ECS instances cluster in existing VPC based on the latest official Amazon ECS AMI (docker 1.12 support)
* Creates IAM security roles and policies to enable access to CloudWatch, ECS, ECR and Autoscaling services for the ECS container instances
* Creates ECS task and service for an example micro service application (nodejs-app)
* The resulting service is only accessible internally, meaning it is only avaible to other services inside the VPC
* Provides service level load balancing via ALB (single access point for the service)
* Provides Auto-scaling on ECS instances cluster and ECS service level (cpu and memory based)
* Provides fault-tolerance and self-healing; failed ECS cluster instance will be removed from it's Autoscaling group and new one launched to replace it
* Provides container instance fault-tolerance and self-healing; the ecs-agent installed on each EC2 instance monitors the health of the containers and restarts the ones that error or crash
* Provides rolling service updates with guarantee that at least 50% of the instances will always be available during the process
* Creates (via user-data and cloud-init) separate Consul client container on each ECS cluster instance that registers the instance with the existing Consul cluster in the VPC
* Creates (via user-data and cloud-init) separate Registrator container on each ECS cluster instance that registers each service with the existing Consul cluster in the VPC
* Collects ECS cluster instance metrics about CPU and RAM and sends them to AWS CloudWatch
* Collects logs from the running application container(s) and sends them to AWS CloudWatch Logs
* Sends SNS email notifications to nominated recipient(s) on scale-up/scale-down events

## Install Terraform

To install `terraform` follow the steps from the install web page [Getting Started](https://www.terraform.io/intro/getting-started/install.html)

## Quick Start

After setting up the binaries go to the cloned terraform directory and create a `.tfvars` file with your AWS IAM API credentials inside the `tf` subdirectory. For example, `provider-credentials.tfvars` with the following content:  
```
provider = {
  access_key = "<AWS_ACCESS_KEY>"
  secret_key = "<AWS_SECRET_KEY>"
  region     = "<AWS_EC2_REGION>"
}
```
Replace `<AWS_EC2_REGION>` with appropriate region.

The global VPC variables are in the `ecs-cluster.tfvars` file so edit this file and adjust the values accordingly. Replace evrything between `<>` with appropriate values, set the `vpc.id` variable to the id of the VPC we want to launch the ECS cluster in and set the VPC CIDR in the `vpc.cidr_block` variable to the appropriate CIDR block of that specific VPC.

Each `.tf` file in the `tf` subdirectory is Terraform playbook where our ECS resources are being created. The `ecs-cluster-vars.tf` file contains all the variables being used and their values are being populated by the settings in the `ecs-cluster.tfvars`. In this way the sensitive data is separated in its own file that we can include in `.gitignore` for example to exclude it from being shared if necessary. Same goes for the `provider-credentials.tfvars` file.

To begin start by issuing the following command inside the `tf` directory:
```bash
$ terraform plan -var-file ecs-cluster.tfvars -var-file provider-credentials.tfvars -out ecs.tfplan
```  
This will create lots of output about the resources that are going to be created and a `ecs.tfplan` plan file containing all the changes that are going to be applied. If this goes without any errors then we can proceed to next step, otherwise we have to go back and fix the errors terraform has printed out. To apply the planned changes then we run:
```bash
$ terraform apply -var-file ecs-cluster.tfvars -var-file provider-credentials.tfvars ecs.tfplan
```  
This will take some time to finish but after that we will have a new ECS cluster deployed in the provided VPC.

Terraform also puts some state into the `terraform.tfstate` file by default. This state file is extremely important; it maps various resource metadata to actual resource IDs so that Terraform knows what it is managing. This file must be saved and distributed to anyone who might run Terraform against the very VPC infrastructure we created so storing this in GitHub repository is the best way to go in order to share a project.

The `app` directory in the repository contains the files needed to build the application docker image. Commands used to build the container and push the image to our DockerHub:

```bash
user@host:~/ecs/app$ sudo docker build -t igoratencompass/nodejs-app .
user@host:~/ecs/app$ sudo docker push igoratencompass/nodejs-app
```

## Further Infrastructure Updates

After we have provisioned our ECS we have to decide how we want to proceed with its maintenance. Any changes made outside of Terraform, like in the EC2 web console, result in Terraform being unaware of it which in turn means Terraform might revert those changes on the next replay. That's why it is very important to choose the AWS console OR the terraform repository as the **only** way of applying changes to our ECS.  

To make changes, like for example update or create a Security Group, we edit the respective `.tf` file and run the above `terraform plan` and `terraform apply` commands. 

## Deleting the Infrastructure

If we need to destroy part of the infrastructure we created, lets say one instance and it's security group we run:  
```bash
$ terraform destroy -var-file ecs-cluster.tfvars -var-file provider-credentials.tfvars -force -target aws_launch_configuration.nat -target aws_autoscaling_group.nat
```  
To destroy the whole ECS we run:  
```bash
$ terraform destroy -var-file ecs-cluster.tfvars -force
```
Terraform is smart enough to determine what order things should be destroyed, same as in the case of creating or updating infrastructure.