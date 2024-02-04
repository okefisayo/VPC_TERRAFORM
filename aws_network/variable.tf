variable "base_ip" {
  description = "Base IP"
  type        = string
}

variable "network_name" {
  description = "Network name"
  type        = string
}

variable "enable_flow_logs" {
  description = "Enable flow logs"
  type        = bool
}

variable "subnet_cidr_info" {
  description = "information needed to provision the subnets in the appropriate availability zone"
  type        = list(object({
    az = string
    public_cidr = string
    private_cidr = string
    data_cidr = string
  }))

  validation {
    condition = length(var.subnet_cidr_info) > 0 && length(var.subnet_cidr_info) <= 3
    error_message = "A min of 1 subnet environment and a max of 3 subnet environment must be provided"
  }
}

variable "public_subnet_nacl_rule" {
    description = "Description of the network acl rule for the public subnets"
    type = list(object({
        rule_no = number
        inbound_rule = bool
        allow_rule = bool
        protocol = string
        port = number
        cidr_block = string
    }))
}

variable "private_subnet_nacl_rule" {
    description = "Description of the network acl rule for the private subnets"
    type = list(object({
        rule_no = number
        inbound_rule = bool
        allow_rule = bool
        protocol = string
        port = number
        cidr_block = string
    }))
}

variable "data_subnet_nacl_rule" {
    description = "Description of the network acl rule for the data subnets"
    type = list(object({
        rule_no = number
        inbound_rule = bool
        allow_rule = bool
        protocol = string
        port = number
        cidr_block = string
    }))
}

variable "vpc_endpoint_service" {
    description = "Information for creating vpc endpoints for at least 2 services. For version 1, we will be supporting only Gateway endpoint "
    type = list(string)
    validation {
    condition = alltrue([for service in var.vpc_endpoint_service : (service == "s3" || service == "dynamodb") ? true : false ]) 
    error_message = "Please specify only service that supports gateway endpoint (s3 or dynamodb)"
  }
}

