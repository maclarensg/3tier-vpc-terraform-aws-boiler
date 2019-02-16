region = "ap-southeast-1"
public_key = ""
name = "terraform-aws"

# VPC
vpc_azs = [ "ap-southeast-1a", "ap-southeast-1b" ]
vpc_cidr = "192.168.0.0/16"
vpc_red_subnets = ["192.168.1.0/24", "192.168.2.0/24"]
vpc_orange_subnets  = ["192.168.101.0/24", "192.168.102.0/24"]
vpc_green_subnets = ["192.168.201.0/24", "192.168.202.0/24"]
vpc_enable_nat_gateway = true
vpc_single_nat_gateway = false
vpc_one_nat_gateway_per_az = true
