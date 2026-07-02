provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

# 1. VPC Personalizada
resource "aws_vpc" "techmarket_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "techmarket-vpc"
  }
}

# 2. Internet Gateway (Para dar salida a internet a los nodos)
resource "aws_internet_gateway" "techmarket_igw" {
  vpc_id = aws_vpc.techmarket_vpc.id

  tags = {
    Name = "techmarket-igw"
  }
}

# 3. Subredes (EKS requiere al menos 2 en distintas Zonas de Disponibilidad)
resource "aws_subnet" "techmarket_subnet_1" {
  vpc_id                  = aws_vpc.techmarket_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "techmarket-subnet-1"
  }
}

resource "aws_subnet" "techmarket_subnet_2" {
  vpc_id                  = aws_vpc.techmarket_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "techmarket-subnet-2"
  }
}

# 4. Tabla de Rutas y Asociaciones
resource "aws_route_table" "techmarket_rt" {
  vpc_id = aws_vpc.techmarket_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.techmarket_igw.id
  }

  tags = {
    Name = "techmarket-rt"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.techmarket_subnet_1.id
  route_table_id = aws_route_table.techmarket_rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.techmarket_subnet_2.id
  route_table_id = aws_route_table.techmarket_rt.id
}

# 5. Clúster EKS apuntando a la nueva VPC
resource "aws_eks_cluster" "techmarket_cluster" {
  name     = "techmarket-cluster"
  role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"

  vpc_config {
    subnet_ids = [
      aws_subnet.techmarket_subnet_1.id,
      aws_subnet.techmarket_subnet_2.id
    ]
  }
}

# 6. Grupo de Nodos apuntando a las nuevas subredes
resource "aws_eks_node_group" "techmarket_nodes" {
  cluster_name    = aws_eks_cluster.techmarket_cluster.name
  node_group_name = "techmarket-node-group"
  node_role_arn   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  subnet_ids      = [
    aws_subnet.techmarket_subnet_1.id,
    aws_subnet.techmarket_subnet_2.id
  ]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]
}