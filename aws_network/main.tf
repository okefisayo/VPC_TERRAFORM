
locals {
    vpc_cidr_block = format("%s/16", var.base_ip)  
    network_name = replace(var.network_name, " ", "_")
}

data "aws_region" "current" {}

# Create the VPC
resource "aws_vpc" "main_vpc" {
  cidr_block       = local.vpc_cidr_block
  instance_tenancy = "default"

  tags = {
    Name = "${local.network_name}_vpc"
  }
}

# Create the internet gateway for the vpc
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${local.network_name}_ig"
  }
}

#Create the public subnets
resource "aws_subnet" "public_subnet" {
    count = length(var.subnet_cidr_info)
    vpc_id     = aws_vpc.main_vpc.id
    cidr_block = var.subnet_cidr_info[count.index].public_cidr
    availability_zone = var.subnet_cidr_info[count.index].az

    tags = {
        Name = "${local.network_name}_public_subnet_${var.subnet_cidr_info[count.index].az}"
    }
}
 
# Creating eip that will be allocated to nat gateways
resource "aws_eip" "nat_gateway" {
    count = length(aws_subnet.public_subnet)
    vpc = true
}

# creating nat gateways for each public subnets. This will be used by the private subnets to communicate with the internet.
resource "aws_nat_gateway" "nat_gateway" {
    count = length(aws_subnet.public_subnet)
    allocation_id = aws_eip.nat_gateway[count.index].id
    subnet_id     = aws_subnet.public_subnet[count.index].id

    tags = {
        Name = "${aws_subnet.public_subnet[count.index].id}_nat_gateway"
    }
    
    depends_on = [aws_internet_gateway.gw]
}

resource "aws_subnet" "private_subnet" {
    count = length(var.subnet_cidr_info)
    vpc_id     = aws_vpc.main_vpc.id
    cidr_block = var.subnet_cidr_info[count.index].private_cidr
    availability_zone = var.subnet_cidr_info[count.index].az

    tags = {
        Name = "${local.network_name}_private_subnet_${var.subnet_cidr_info[count.index].az}"
    }
}

resource "aws_subnet" "data_subnet" {
    count = length(var.subnet_cidr_info)
    vpc_id     = aws_vpc.main_vpc.id
    cidr_block = var.subnet_cidr_info[count.index].data_cidr
    availability_zone = var.subnet_cidr_info[count.index].az

    tags = {
        Name = "${local.network_name}_data_subnet_${var.subnet_cidr_info[count.index].az}"
    }
}

# creating public route table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "${local.vpc_cidr_block}"
    gateway_id = "local"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${local.network_name}_public_route_table"
  }
}

# creating private route tables. This will be mapped to the private and data subnets
resource "aws_route_table" "private_route_table" {
    count = length(aws_nat_gateway.nat_gateway)
    # for_each = aws_nat_gateway.nat_gateway
    vpc_id = aws_vpc.main_vpc.id

    route {
        cidr_block = "${local.vpc_cidr_block}"
        gateway_id = "local"
    }

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_nat_gateway.nat_gateway[count.index].id
    }

    tags = {
        Name = "${local.network_name}_private_route_table_${count.index}"
    }
}

# Associating the public subnet with the public route table
resource "aws_route_table_association" "public_subnet_route_table_association" {
    count = length(aws_subnet.public_subnet)
    subnet_id      = aws_subnet.public_subnet[count.index].id
    route_table_id = aws_route_table.public_route_table.id
}

# Associating the private subnet with the private route table
resource "aws_route_table_association" "private_subnet_route_table_association" {
    count = length(aws_subnet.private_subnet)
    subnet_id      = aws_subnet.private_subnet[count.index].id
    route_table_id = aws_route_table.private_route_table[count.index].id
}

# Associating the data subnet with the data route table
resource "aws_route_table_association" "data_subnet_route_table_association" {
    count = length(aws_subnet.private_subnet)
    subnet_id      = aws_subnet.data_subnet[count.index].id
    route_table_id = aws_route_table.private_route_table[count.index].id
}

### Section for provisioning network acl and setting nacl rules

# provision nacl for public subnet
resource "aws_network_acl" "public_subnet_nacl" {
    vpc_id = aws_vpc.main_vpc.id
    subnet_ids = [for subnet in aws_subnet.public_subnet : subnet.id]

    tags = {
        Name = "${local.network_name}_public_subnet_nacl"
    }
}

# provision nacl for private subnet
resource "aws_network_acl" "private_subnet_nacl" {
    vpc_id = aws_vpc.main_vpc.id
    subnet_ids = [for subnet in aws_subnet.private_subnet : subnet.id]

    tags = {
        Name = "${local.network_name}_private_subnet_nacl"
    }
}

# provision nacl for data subnet
resource "aws_network_acl" "data_subnet_nacl" {
    vpc_id = aws_vpc.main_vpc.id
    subnet_ids = [for subnet in aws_subnet.data_subnet : subnet.id]

    tags = {
        Name = "${local.network_name}_data_subnet_nacl"
    }
}

# set nacl rule for public subnet
resource "aws_network_acl_rule" "public_subnet_nacl_rule" {
    for_each = { for idx, rule in var.public_subnet_nacl_rule : idx => rule }
    network_acl_id = aws_network_acl.public_subnet_nacl.id
    rule_number    = each.value.rule_no
    egress         = each.value.inbound_rule ? false : true
    protocol       = each.value.protocol
    rule_action    = each.value.allow_rule ? "allow" : "deny"
    cidr_block     = each.value.cidr_block
    from_port      = each.value.port
    to_port        = each.value.port

    depends_on = [ aws_network_acl.public_subnet_nacl ]
}

# set nacl rule for private subnet
resource "aws_network_acl_rule" "private_subnet_nacl_rule" {
    for_each = { for idx, rule in var.private_subnet_nacl_rule : idx => rule }
    network_acl_id = aws_network_acl.private_subnet_nacl.id
    rule_number    = each.value.rule_no
    egress         = each.value.inbound_rule ? false : true
    protocol       = each.value.protocol
    rule_action    = each.value.allow_rule ? "allow" : "deny"
    cidr_block     = each.value.cidr_block
    from_port      = each.value.port
    to_port        = each.value.port

    depends_on = [ aws_network_acl.private_subnet_nacl ]
}

# set nacl rule for data subnet
resource "aws_network_acl_rule" "data_subnet_nacl_rule" {
    for_each = { for idx, rule in var.data_subnet_nacl_rule : idx => rule }
    network_acl_id = aws_network_acl.data_subnet_nacl.id
    rule_number    = each.value.rule_no
    egress         = each.value.inbound_rule ? false : true
    protocol       = each.value.protocol
    rule_action    = each.value.allow_rule ? "allow" : "deny"
    cidr_block     = each.value.cidr_block
    from_port      = each.value.port
    to_port        = each.value.port

    depends_on = [ aws_network_acl.data_subnet_nacl ]
}

### Section for enabling flow logs for vpc

# provision the cloudwatch log group
resource "aws_cloudwatch_log_group" "log_group" {
    count = var.enable_flow_logs ? 1 : 0
    name = "${local.network_name}_log_group"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_role" {
    count = var.enable_flow_logs ? 1 : 0
    name = "${local.network_name}_flow_log_role"
    assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "aws_iam_policy_document" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "aws_iam_role_policy" {
    count = var.enable_flow_logs ? 1 : 0
    name   = "${local.network_name}_role_policy"
    role   = aws_iam_role.iam_role[0].id
    policy = data.aws_iam_policy_document.aws_iam_policy_document.json
}

resource "aws_flow_log" "aws_flow_log" {
    count = var.enable_flow_logs ? 1 : 0
    iam_role_arn    = aws_iam_role.iam_role[0].arn
    log_destination = aws_cloudwatch_log_group.log_group[0].arn
    traffic_type    = "ALL"
    vpc_id          = aws_vpc.main_vpc.id
}


### Section for provision vpc endpoint
resource "aws_vpc_endpoint" "endpoint" {
    for_each = { for service in var.vpc_endpoint_service: format("com.amazonaws.%s.%s", data.aws_region.current.name, lower(service)) => service }
    vpc_id       = aws_vpc.main_vpc.id
    service_name = each.key
    route_table_ids = [ for rt in aws_route_table.private_route_table : rt.id]

    tags = {
        Name = "${local.network_name}_${each.value}_endpoint"
    }
}