provider "aws" {
  region = local.region
}

provider "aws" {
  alias  = "peer-region"
  region = local.peer_region
}

data "aws_caller_identity" "current" {}

locals {
  name = "terraform-aws-modules"

  region      = "us-east-1"
  peer_region = "us-west-2"

  account_id = data.aws_caller_identity.current.account_id

  tags = {
    Example    = local.name
    GithubRepo = "terraform-aws-transit-gateway"
  }
}

################################################################################
# Transit Gateway Module
################################################################################

module "transit_gateway" {
  source = "../../"

  name                               = local.name
  description                        = "Example Transit Gateway connecting multiple VPCs"
  amazon_side_asn                    = 64532
  security_group_referencing_support = true
  transit_gateway_cidr_blocks        = ["10.99.0.0/24"]

  vpc_attachment_defaults = {
    transit_gateway_default_route_table_association = false
    transit_gateway_default_route_table_propagation = false
  }

  vpc_attachments = {
    vpc1 = {
      vpc_id                             = module.vpc1.vpc_id
      subnet_ids                         = module.vpc1.private_subnets
      ipv6_support                       = true
      security_group_referencing_support = true

      vpc_routes = {
        tgw_route = {
          route_table_ids         = module.vpc1.private_route_table_ids
          destination_cidr_blocks = ["10.0.0.0/8"]
        }
      }
    }
    vpc2 = {
      vpc_id                             = module.vpc2.vpc_id
      subnet_ids                         = module.vpc2.private_subnets
      security_group_referencing_support = true

      vpc_routes = {
        tgw_route = {
          route_table_ids         = module.vpc2.private_route_table_ids
          destination_cidr_blocks = ["10.0.0.0/8"]
        }
      }
    }
    vpc3 = {
      vpc_id     = module.vpc3.vpc_id
      subnet_ids = module.vpc3.private_subnets

      vpc_routes = {
        tgw_route = {
          route_table_ids         = module.vpc3.private_route_table_ids
          destination_cidr_blocks = ["10.0.0.0/8"]
        }
      }
    }
  }

  peering_attachments = {
    west-peer = {
      peer_region             = local.peer_region
      peer_account_id         = module.transit_gateway_peer_region.owner_id
      peer_transit_gateway_id = module.transit_gateway_peer_region.id
    }
  }

  route_tables = {
    hub = {
      associations = ["vpc1"]
      propagations = ["vpc2", "vpc3"]

      static_routes = [
        { destination_cidr_block = "10.0.0.0/8", attachment = "west-peer" },
        { destination_cidr_block = "0.0.0.0/0", blackhole = true },
      ]
    }
    spoke = {
      associations = ["vpc2", "vpc3", "west-peer"]
      propagations = ["vpc1"]

      static_routes = [
        { destination_cidr_block = "0.0.0.0/0", blackhole = true }
      ]
    }
  }

  tags = local.tags
}

module "transit_gateway_peer_region" {
  source = "../../"

  providers = {
    aws = aws.peer-region
  }

  name        = local.name
  description = "Example Transit Gateway in a different region connecting multiple VPCs"

  amazon_side_asn = 64533

  vpc_attachment_defaults = {
    transit_gateway_default_route_table_association = false
    transit_gateway_default_route_table_propagation = false
  }

  vpc_attachments = {

    vpc4 = {
      vpc_id     = module.vpc4.vpc_id
      subnet_ids = module.vpc4.private_subnets

      vpc_routes = {
        tgw_route = {
          route_table_ids         = module.vpc4.private_route_table_ids
          destination_cidr_blocks = ["10.0.0.0/8"]
        }
      }
    }

    vpc5 = {
      accept_shared_attachment = true
      vpc_attachment_id        = module.transit_gateway_attachment_peer_account.vpc_attachments["vpc5"].id
    }
  }

  peering_attachments = {
    east-peer = {
      accept_peering_attachment = true
      peering_attachment_id     = module.transit_gateway.peering_attachments["west-peer"].id
    }
  }

  route_tables = {
    hub = {
      associations = ["east-peer"]
      propagations = ["vpc4", "vpc5"]

      static_routes = [
        { destination_cidr_block = "0.0.0.0/0", blackhole = true },
      ]
    }
    spoke = {
      associations = ["vpc4", "vpc5"]
      propagations = []

      static_routes = [
        { destination_cidr_block = "10.0.0.0/8", attachment = "east-peer" },
        { destination_cidr_block = "0.0.0.0/0", blackhole = true }
      ]
    }
  }

  enable_ram_share = true
  ram_principals   = [data.aws_caller_identity.peer_account.account_id]

  tags = local.tags
}

################################################################################
# Supporting resources
################################################################################

locals {
  vpc1_cidr = "10.0.0.0/16"
  vpc2_cidr = "10.20.0.0/16"
  vpc3_cidr = "10.30.0.0/16"
  vpc4_cidr = "10.40.0.0/16"
  vpc5_cidr = "10.50.0.0/16"

  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
  azs_peer = slice(data.aws_availability_zones.available_peer.names, 0, 3)
}

data "aws_availability_zones" "available" {
  # Exclude local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_availability_zones" "available_peer" {
  provider = aws.peer-region
  # Exclude local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

module "vpc1" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name}-vpc1"
  cidr = local.vpc1_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc1_cidr, 4, k)]

  enable_ipv6                                    = true
  private_subnet_assign_ipv6_address_on_creation = true
  private_subnet_ipv6_prefixes                   = [0, 1, 2]

  tags = local.tags
}

module "vpc2" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name}-vpc2"
  cidr = local.vpc2_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc2_cidr, 4, k)]

  tags = local.tags
}

module "vpc3" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name}-vpc3"
  cidr = local.vpc3_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc3_cidr, 4, k)]

  tags = local.tags
}

module "vpc4" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.peer-region
  }

  name = "${local.name}-vpc4"
  cidr = local.vpc4_cidr

  azs             = local.azs_peer
  private_subnets = [for k, v in local.azs_peer : cidrsubnet(local.vpc4_cidr, 4, k)]

  tags = local.tags
}

resource "random_pet" "this" {
  length = 2
}

module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket        = "${local.name}-${random_pet.this.id}"
  policy        = data.aws_iam_policy_document.flow_log_s3.json
  force_destroy = true

  tags = local.tags
}

data "aws_iam_policy_document" "flow_log_s3" {
  statement {
    sid = "AWSLogDeliveryWrite"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${local.name}-${random_pet.this.id}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:${local.region}:${local.account_id}:*"]
    }
  }

  statement {
    sid = "AWSLogDeliveryAclCheck"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions = [
      "s3:Get*",
      "s3:List*",
    ]
    resources = ["arn:aws:s3:::${local.name}-${random_pet.this.id}"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:${local.region}:${local.account_id}:*"]
    }
  }
}
