terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.34.0"
    }
  }

  required_version = "~> 1.3"
}

provider "aws" {
  region = "us-east-1"
}

# Filter out local zones, which are not currently supported 
# with managed node groups
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
      azs  = slice(data.aws_availability_zones.available.names, 0, 2)
      public_cidr = ["10.0.1.0/24", "10.0.2.0/24"]
      private_cidr = ["10.0.3.0/24", "10.0.4.0/24"]
      data_cidr = ["10.0.5.0/24", "10.0.6.0/24"]
}


module "render_health_vpc" {
    source = "./aws_network"
    network_name = "olu group"
    base_ip = "10.0.0.0"
    enable_flow_logs = true
    vpc_endpoint_service = ["s3", "dynamodb"]

    subnet_cidr_info = [for i, az in local.azs : {
      az = az
      public_cidr = local.public_cidr[i]
      private_cidr = local.private_cidr[i]
      data_cidr = local.data_cidr[i]
    }]

    public_subnet_nacl_rule = concat([ for i, cidr in local.private_cidr : {
        rule_no = 100 + (i * 10)
        inbound_rule = false
        allow_rule = true
        protocol = "tcp"
        port = 8080
        cidr_block = cidr
    }], 
    [{
        rule_no = 100
        inbound_rule = true
        allow_rule = true
        protocol = "tcp"
        port = 80
        cidr_block = "0.0.0.0/0"
    }])

    private_subnet_nacl_rule = concat([ for i, cidr in local.data_cidr : {
        rule_no = 100 + (i * 10)
        inbound_rule = false
        allow_rule = true
        protocol = "tcp"
        port = 3306
        cidr_block = cidr
    }], 
    [ for i, cidr in local.public_cidr : {
        rule_no = 100 + (i * 10)
        inbound_rule = true
        allow_rule = true
        protocol = "tcp"
        port = 8080
        cidr_block = cidr
    }])

    data_subnet_nacl_rule = concat(
    [ for i, cidr in local.private_cidr : {
        rule_no = 100 + (i * 10)
        inbound_rule = true
        allow_rule = true
        protocol = "tcp"
        port = 3306
        cidr_block = cidr
    }])
}









