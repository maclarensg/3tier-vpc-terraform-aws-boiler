
##########################
# 3tier VPC Architecture #
##########################
resource "aws_vpc" "vpc_3tier" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name      = "3tier"
    BuildWith = "terraform"
  }
}

##################################
# Red Zone / Access or DMZ layer #
##################################
resource "aws_subnet" "red_zone" {
  count = "${length(var.vpc_red_subnets)}"

  vpc_id                  = "${aws_vpc.vpc_3tier.id}"
  cidr_block              = "${var.vpc_red_subnets[count.index]}"
  availability_zone       = "${element(var.vpc_azs, count.index)}"
  map_public_ip_on_launch = true

  tags = {
    Name      = "${format("red_subnet_%02d", count.index + 1)}"
    BuildWith = "terraform"
  }
}

###########################
# Orange Zone / App layer #
###########################
resource "aws_subnet" "orange_zone" {
  count = "${length(var.vpc_orange_subnets)}"

  vpc_id                  = "${aws_vpc.vpc_3tier.id}"
  cidr_block              = "${var.vpc_orange_subnets[count.index]}"
  availability_zone       = "${element(var.vpc_azs, count.index)}"
  
  
  tags = {
    Name      = "${format("orange_subnet_%02d", count.index + 1)}"
    BuildWith = "terraform"
  }
}

#########################
# Green Zone / DB Layer #
#########################
resource "aws_subnet" "green_zone" {
  count = "${length(var.vpc_green_subnets)}"

  vpc_id                  = "${aws_vpc.vpc_3tier.id}"
  cidr_block              = "${var.vpc_green_subnets[count.index]}"
  availability_zone       = "${element(var.vpc_azs, count.index)}"
  
  tags = {
    Name      = "${format("green_subnet_%02d", count.index + 1)}"
    BuildWith = "terraform"
  }
}
####################################
# Internet Gateway, NAT and Routes #
####################################
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = "${ aws_vpc.vpc_3tier.id }"

  tags = {
    Name      = "Internet Gateway"
    BuildWith = "terraform"
  }
}

# adding an elastic IP
resource "aws_eip" "elastic_ip_for_nat" {
  count=2
  vpc        = true
  depends_on = ["aws_internet_gateway.internet_gateway"]
}


# creating the NAT gateway
resource "aws_nat_gateway" "nat" {
  count = "${length(var.vpc_red_subnets)}"

  allocation_id = "${ element(aws_eip.elastic_ip_for_nat.*.id, count.index) }"
  subnet_id     = "${ element(aws_subnet.red_zone.*.id, count.index) }"
  depends_on    = ["aws_internet_gateway.internet_gateway"]

  tags = {
    Name      = "${format("NAT Gateway %02d", count.index + 1)}"
    BuildWith = "terraform"
  }
}

### Red Zone Route Table ###
# creating red zone routing table 
resource "aws_route_table" "redzone_route_table" {
  count = "${length(var.vpc_red_subnets)}"

  vpc_id = "${ aws_vpc.vpc_3tier.id }"
  

  tags {
    Name      = "${format("red_route_table_az%02d", count.index + 1)}"
    BuildWith = "terraform"
  }
}
resource "aws_route" "red_default_route" {
  count="${length(var.vpc_red_subnets)}"
  route_table_id         = "${ element(aws_route_table.redzone_route_table.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id         = "${aws_internet_gateway.internet_gateway.id}"
}


### Orange Zone Route Table ###
# creating orange zone routing table 
resource "aws_route_table" "orange_route_table" {
  count = "${length(var.vpc_orange_subnets)}"

  vpc_id = "${ aws_vpc.vpc_3tier.id }"
  

  tags {
    Name      = "${format("orange_route_table_az%02d", count.index + 1)}"
    BuildWith = "terraform"
  }
}

# adding orange route table to nat
resource "aws_route" "orange_route" {
  count="${length(var.vpc_orange_subnets)}"
  route_table_id         = "${ element(aws_route_table.orange_route_table.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${element(aws_nat_gateway.nat.*.id, count.index)}"
}

# associate subnet orange subnet to orange route table
resource "aws_route_table_association" "orange_subnet_association" {
  count          = "${length(var.vpc_orange_subnets)}"
  subnet_id      = "${ element(aws_subnet.orange_zone.*.id, count.index) }"
  route_table_id = "${ element(aws_route_table.orange_route_table.*.id, count.index) }"
}

### Green Zone Route Table ###
# creating grren zone routing table 
resource "aws_route_table" "green_route_table" {
  count = "${length(var.vpc_green_subnets)}"

  vpc_id = "${ aws_vpc.vpc_3tier.id }"
  

  tags {
    Name      = "${format("green_route_table_az%02d", count.index + 1)}"
    BuildWith = "terraform"
  }
}

# adding green route table to nat
resource "aws_route" "green_route" {
  count="${length(var.vpc_green_subnets)}"
  route_table_id         = "${ element(aws_route_table.green_route_table.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${element(aws_nat_gateway.nat.*.id, count.index)}"
}

# associate subnet green subnet to green route table
resource "aws_route_table_association" "green_subnet_association" {
  count          = "${length(var.vpc_green_subnets)}"
  subnet_id      = "${ element(aws_subnet.green_zone.*.id, count.index) }"
  route_table_id = "${ element(aws_route_table.green_route_table.*.id, count.index) }"
}

########
# ACLs #
########

### Red Zone ###
resource "aws_network_acl" "red_zone" {
  vpc_id = "${aws_vpc.vpc_3tier.id}"
   subnet_ids = ["${aws_subnet.red_zone.*.id}"]

  tags = {
    Name = "Red Zone"
    Tier = "Red Zone"
  }
}

resource "aws_network_acl_rule" "red_zone_allow_red_subnet" {
  count          = "${length(var.vpc_red_subnets)}"

  network_acl_id = "${aws_network_acl.red_zone.id}"
  rule_number    = "${200 + count.index}"
  egress         = false
  protocol       = "all"
  rule_action    = "allow"
  cidr_block     = "${var.vpc_red_subnets[count.index]}"
}

resource "aws_network_acl_rule" "red_zone_allow_orange_subnet" {
  count          = "${length(var.vpc_orange_subnets)}"

  network_acl_id = "${aws_network_acl.red_zone.id}"
  rule_number    = "${200 + count.index + 2}"
  egress         = false
  protocol       = "all"
  rule_action    = "allow"
  cidr_block     = "${var.vpc_orange_subnets[count.index]}"
}

resource "aws_network_acl_rule" "red_zone_allow_outgoing" {

  network_acl_id = "${aws_network_acl.red_zone.id}"
  rule_number    = 100
  egress         = true
  protocol       = "all"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

### Orange Zone ###
resource "aws_network_acl" "orange_zone" {
  vpc_id = "${aws_vpc.vpc_3tier.id}"
   subnet_ids = ["${aws_subnet.orange_zone.*.id}"]

  tags = {
    Name = "Orange Zone"
    Tier = "Orange Zone"
  }
}

resource "aws_network_acl_rule" "orange_zone_allow_orange_subnet" {
  count          = "${length(var.vpc_orange_subnets)}"

  network_acl_id = "${aws_network_acl.orange_zone.id}"
  rule_number    = "${200 + count.index}"
  egress         = false
  protocol       = "all"
  rule_action    = "allow"
  cidr_block     = "${var.vpc_orange_subnets[count.index]}"
}

resource "aws_network_acl_rule" "orange_zone_allow_red_subnet" {
  count          = "${length(var.vpc_red_subnets)}"

  network_acl_id = "${aws_network_acl.orange_zone.id}"
  rule_number    = "${200 + count.index + 2}"
  egress         = false
  protocol       = "all"
  rule_action    = "allow"
  cidr_block     = "${var.vpc_red_subnets[count.index]}"
}

resource "aws_network_acl_rule" "orange_zone_allow_outgoing" {

  network_acl_id = "${aws_network_acl.orange_zone.id}"
  rule_number    = 100
  egress         = true
  protocol       = "all"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

### Green Zone ###
resource "aws_network_acl" "green_zone" {
  vpc_id = "${aws_vpc.vpc_3tier.id}"
   subnet_ids = ["${aws_subnet.green_zone.*.id}"]

  tags = {
    Name = "Green Zone"
    Tier = "Green Zone"
  }
}
resource "aws_network_acl_rule" "green_zone_allow_green_subnet" {
  count          = "${length(var.vpc_green_subnets)}"

  network_acl_id = "${aws_network_acl.green_zone.id}"
  rule_number    = "${200 + count.index}"
  egress         = false
  protocol       = "all"
  rule_action    = "allow"
  cidr_block     = "${var.vpc_green_subnets[count.index]}"
}

resource "aws_network_acl_rule" "green_zone_allow_orange_subnet" {
  count          = "${length(var.vpc_orange_subnets)}"

  network_acl_id = "${aws_network_acl.green_zone.id}"
  rule_number    = "${200 + count.index + 2}"
  egress         = false
  protocol       = "all"
  rule_action    = "allow"
  cidr_block     = "${var.vpc_orange_subnets[count.index]}"
}

resource "aws_network_acl_rule" "green_zone_allow_outgoing" {

  network_acl_id = "${aws_network_acl.green_zone.id}"
  rule_number    = 100
  egress         = true
  protocol       = "all"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}


########################
# Variables Definition #
########################
variable "vpc_cidr" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overriden"
  default     = "0.0.0.0/0"
}

variable "vpc_red_subnets" {
  description = "A list of public subnets inside the VPC"
  default     = []
}

variable "vpc_orange_subnets" {
  description = "A list of private subnets inside the VPC"
  default     = []
}

variable "vpc_green_subnets" {
  type        = "list"
  description = "A list of database subnets"
  default     = []
}

variable "vpc_azs" {
  description = "A list of availability zones in the region"
  default     = []
}

variable "vpc_enable_nat_gateway" {
  description = "Should be true if you want to provision NAT Gateways for each of your private networks"
  default     = false
}

variable "vpc_single_nat_gateway" {
  description = "Should be true if you want to provision a single shared NAT Gateway across all of your private networks"
  default     = false
}

variable "vpc_one_nat_gateway_per_az" {
  description = "Should be true if you want only one NAT Gateway per availability zone. Requires `var.azs` to be set, and the number of `public_subnets` created to be greater than or equal to the number of availability zones specified in `var.azs`."
  default     = false
}