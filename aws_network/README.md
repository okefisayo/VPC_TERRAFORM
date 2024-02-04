This reusable module is used to deploy aws vpc and other networking components needed to provision a three tier architecture.  This includes
* creating the vpc
* creating 3 subnets per availability domain - one public subnet, one private subnet and one data subnet. A maximum of nine subnets can be created
* Provisioning and configuring route tables for the subnets
* Provisioning and configuring network acls for the subnets

To use this module, the following input variable will need to be provided
* base_ip: The base IP address for the vpc
* network_name: name for the vpc network
* subnet_cidr_info: A list of objects that contains the cidr info for the the subnets in an AZ. 
    * az = The availability zone 
    * public_cidr = The IPv4 CIDR block for the public subnet.
    * private_cidr = The IPv4 CIDR block for the private subnet.
    * data_cidr = The IPv4 CIDR block for the data subnet.
* public_subnet_nacl_rule: A list of objects that contains the rules for the network acl that will be assoicated with the public subnet
    * rule_no = the rule number for the entry
    * inbound_rule = (bool) indicates wheather this is an inbound rule or not
    * allow_rule = (bool) indicated wheather this is an allow rule or not
    * protocl: The protocol
    * port
    * cidr_block = The network range to allow or deny
* private_subnet_nacl_rule: Same as public_subnet_nacl_rule, only the rules are associated with the private subnets
* data_subnet_nacl_rule: Same as public_subnet_nacl_rule, only the rules are associated with the dat subnets
* enable_flow_logs: whether or not to enable vpc flow logs
* vpc_endpoint_service: Service to create vpc endpoint forl.