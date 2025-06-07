

###################################################################################
# Create a VPC / 2_Public_Subnets for teh NAT and ALB / Internet_Gateway
###################################################################################

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "App_VPC_IaC"
  }
}


# Create a public subnet
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.0.0/28"
  availability_zone = "us-east-1a"   	# Replace with your preferred AZ
  map_public_ip_on_launch = true  		# Enable this to auto-assign public IPs
  tags = {
    Name = "Public_Subnet_1_IaC"
  }
}


# Create a second public subnet in a different AZ
resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.0.16/28" 			# Make sure the CIDR block doesn't overlap with the first subnet
  availability_zone = "us-east-1b"   			# Replace with another AZ in your preferred region
  map_public_ip_on_launch = true  				# Enable this to auto-assign public IPs
  tags = {
    Name = "Public_Subnet_2_IaC"
  }
}


# Create an internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "Internet_Gateway_IaC"
  }
}



##################################################################
# Create NAT GATEWAY in only 1 public subnet in 1 AZ
##################################################################

# NAT Gateway in public subnet AZ1
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
}



##################################################################
# Create 2 private_subnets for the MySQL DB / ASG / SEC GROUP 
##################################################################


# Create a private subnet in the same AZ as the first public subnet
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.0.32/28"          # Make sure the CIDR block doesn't overlap with the public subnet
  availability_zone = "us-east-1a"            # Same AZ as the first public subnet
  map_public_ip_on_launch = false             # DO NOT Auto-assign public IPs!
  tags = {
    Name = "Private_Subnet_1_IaC"
  }
}



# Create a private subnet in the same AZ as the second public subnet
resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.0.48/28"          # Make sure the CIDR block doesn't overlap with the public subnet
  availability_zone = "us-east-1b"            # Same AZ as the second public subnet
  map_public_ip_on_launch = false             # DO NOT Auto-assign public IPs!
  tags = {
    Name = "Private_Subnet_2_IaC"
  }
}



# Create a subnet group for the RDS instance
resource "aws_db_subnet_group" "mydb_subnet_group" {
  name       = "mydb_subnet_group"
  subnet_ids = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]

  tags = {
    Name = "App_DB_Subnet_Group_IaC"
  }
}



##############################################################################
# Create Route_Tables for both public and private subnets: 
##############################################################################


############### PUBLIC ROUTING TABLE and SUBNETS: ###############
# All traffic from the 2 public subnets are going to the Internet Gateway: 
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # Any traffic destined for an address outside the VPC will be directed to the VPC internet gateway
    gateway_id = aws_internet_gateway.igw.id    
  }

  tags = {
    Name = "public_rt_IaC"
  }
}

# Associate the route table with public_subnet_1
resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

# Associate the route table with public_subnet_2
resource "aws_route_table_association" "public_rt_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}


############### PRIVATE ROUTING TABLE and SUBNETS: ###############
# All traffic from the private subnets are going to the NAT Gateway: 
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

##### PRIVATE SUBNETS: ##### 
# Associate the route table with the 1st PRIVATE subnet:
resource "aws_route_table_association" "private_rt_assoc" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

# Associate the route table with the 2nd PRIVATE subnet: 
resource "aws_route_table_association" "private_rt_assoc_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}


##############################################################################
# Create Route53 Private Zone for the private subnets: 
##############################################################################

resource "aws_route53_zone" "private" {
  name = "internal.xxsapxx.local"
  vpc {
    vpc_id = aws_vpc.my_vpc.id
  }
  comment = "Private zone for internal DNS resolution"
}

# Pass the ZONE_ID Variable to the userdata script -- (IN RDS CREATION BLOCK)