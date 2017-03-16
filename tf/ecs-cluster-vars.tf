/*=== DATA SOURCES ===*/
data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}
data "aws_route53_zone" "selected" {
  name         = "${var.enc_domain["name"]}."
  private_zone = false
}

/* Fetch the AWS ECS Optimized Linux AMI. When we launch this AMI for first time we 
have to accept the terms and conditions on this webpage or the EC2 instances will
fail to launch: https://aws.amazon.com/marketplace/pp/B00U6QTYI2 (done on 4/3/17) */
data "aws_ami" "ecs" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized"]
  }
}

/*=== VARIABLES ===*/
variable "provider" {
    type    = "map"
    default = {
        access_key = "unknown"
        secret_key = "unknown"
        region     = "unknown"
    }
}

variable "vpc" {
    type    = "map"
    default = {
        "id"          = "unknown"
        "tag"         = "unknown"
        "cidr_block"  = "unknown"
        "subnet_bits" = "unknown"
        "owner_id"    = "unknown"
        "sns_topic"   = "unknown"
    }
}

variable "azs" {
    type    = "map"
    default = {
        "ap-southeast-2" = "ap-southeast-2a,ap-southeast-2b,ap-southeast-2c"
        "eu-west-1"      = "eu-west-1a,eu-west-1b,eu-west-1c"
        "us-west-1"      = "us-west-1b,us-west-1c"
        "us-west-2"      = "us-west-2a,us-west-2b,us-west-2c"
        "us-east-1"      = "us-east-1c,us-west-1d,us-west-1e"
    }
}

variable "vpc_subnets" {
    type    = "map"
    default = {
        "<VPC-ID>" = "<SUBNET-ID>,<SUBNET-ID>,<SUBNET-ID>"
    }
}

variable "ecs" {
  type    = "map"
  default = {
    "cluster_name"         = "unknown"
    "instance_type"        = "unknown"
    "file_name"            = "unknown"
    "role_arn"             = "unknown"
    "termination_policies" = "Default"
  }
}

variable "consul" {
  type    = "map"
  default = {
    "data_center"        = "unknown"
    "instance_type"      = "unknown"
    "version"            = "unknown"
    "encrypt_key"        = "unknown"
    "cert_download_user" = "unknown"
    "servers"            = "unknown"
  }
}

variable "app" {
  default = {
    "name"              = "unknown"
    "volume_mount"      = "unknown"
    "enc_env"           = "unknown"
    "oracle_jdk"        = "8"
    "elb_ssl_cert_arn"  = "unknown"
    "elb_hc_uri"        = "unknown"
    "listen_port_http"  = "8080"
    "listen_port_https" = "443"
    "min_capacity"      = "unknown"
    "max_capacity"      = "unknown"
    "image"             = "unknown"
    "version"           = "unknown"
    "cpu"               = "unknown"
    "memory"            = "unknown"
    "file_name"         = "unknown"
    "role_arn"          = "unknown"
  }
}

variable "instance_type" {
    default = "t1.micro"
}

variable "key_name" {
    default = "unknown"
}

variable "munin_cidr_block" {
    default = "unknown" 
}

variable "manager_cidr_block" {
    default = "unknown" 
}

variable "nfs_cidr_block" {
    default = "unknown"
}

/* Ubuntu Trusty 14.04 LTS (x64) */
variable "images" {
    type    = "map"
    default = {
        eu-west-1      = "ami-47a23a30"
        ap-southeast-2 = "ami-6c14310f"
        us-east-1      = "ami-2d39803a"
        us-west-2      = "ami-d732f0b7"
    }
}

variable "enc_domain" {
    type    = "map"
    default = {
        name    = "unknown"
        zone_id = "unknown"
    }
}