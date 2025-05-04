provider "aws" {
  region = "us-east-1"
}

resource "aws_db_instance" "rds_instance" {
  allocated_storage      = 10
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t3.micro"
  username               = "admin"
  password               = var.db_pass
  parameter_group_name   = "default.mysql5.7"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.tier_db_subnet_v2.name
  tags = {
    Name = "RDSInstance"
  }
}


resource "aws_instance" "dbserver" {
  ami                         = "ami-0e449927258d45bc4"
  instance_type               = "t2.micro"
  key_name                    = "twogem"
  subnet_id                   = aws_subnet.tier_private_subnet_a.id
  vpc_security_group_ids      = [aws_security_group.db_sg.id]
  associate_public_ip_address = false
  tags = {
    Name = "DBServerInstance"
  }
}

resource "aws_instance" "webserver" {
  ami                         = "ami-0e449927258d45bc4"
  instance_type               = "t2.micro"
  key_name                    = "twogem"
  subnet_id                   = aws_subnet.tier_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.webserver_sg.id]
  associate_public_ip_address = true
  user_data                   = file("nginx.sh")
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
  tags = {
    Name = "WebServerInstance"
  }
}

resource "aws_vpc" "tier_vpc" {
  cidr_block         = "10.0.0.0/16"
  enable_dns_support = true

  tags = {
    Name = "TierVPC"
  }
}

resource "aws_subnet" "tier_public_subnet" {
  vpc_id                  = aws_vpc.tier_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "tierPublicSubnet"
  }

}

resource "aws_subnet" "tier_private_subnet_a" {
  vpc_id            = aws_vpc.tier_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "tierPrivateSubnetA"
  }
}

resource "aws_subnet" "tier_private_subnet_b" {
  vpc_id            = aws_vpc.tier_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"

  tags = {
    name = "tierPrivateSubnetB"
  }
}


resource "aws_internet_gateway" "tier_igw" {
  vpc_id = aws_vpc.tier_vpc.id
  tags = {
    Name = "tierIGW"
  }
}

resource "aws_route_table" "tier_public_route_table" {
  vpc_id = aws_vpc.tier_vpc.id
  tags = {
    Name = "tierPublicRouteTable"
  }
}

resource "aws_route" "tier_public_route" {
  route_table_id         = aws_route_table.tier_public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.tier_igw.id

}

resource "aws_route_table" "tier_private_route_table" {
  vpc_id = aws_vpc.tier_vpc.id

}

resource "aws_route_table_association" "tier_public_subnet_association" {
  subnet_id      = aws_subnet.tier_public_subnet.id
  route_table_id = aws_route_table.tier_public_route_table.id
}

resource "aws_route_table_association" "tier_private_subnet_association_a" {
  subnet_id      = aws_subnet.tier_private_subnet_a.id
  route_table_id = aws_route_table.tier_private_route_table.id
}

resource "aws_route_table_association" "tier_private_subnet_association_b" {
  subnet_id      = aws_subnet.tier_private_subnet_b.id
  route_table_id = aws_route_table.tier_private_route_table.id
}

resource "aws_db_subnet_group" "tier_db_subnet_v2" {
  name       = "tier_db_subnet_group"
  subnet_ids = [aws_subnet.tier_private_subnet_a.id, aws_subnet.tier_private_subnet_b.id]

  tags = {
    Name = "TierDBSubnetGroup"
  }
}


resource "aws_security_group" "webserver_sg" {
  name        = "webserver_sg"
  description = "Allow HTTP and SSH traffic"
  vpc_id      = aws_vpc.tier_vpc.id


  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_security_group" "db_sg" {
  name        = "db_sg"
  description = "Allow MySQL traffic"
  vpc_id      = aws_vpc.tier_vpc.id


  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "webserver_to_db" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db_sg.id
  source_security_group_id = aws_security_group.webserver_sg.id
}

resource "aws_s3_bucket" "backup_bucket" {
  bucket = "new-tier-bucket-lj"
  tags = {
    Name        = "BackupBucket"
    Environment = "Production"
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2_s3_access_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_s3_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_s3_access_profile"
  role = aws_iam_role.ec2_role.name
}





  
  

 

