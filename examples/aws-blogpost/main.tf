# Network Service Account
provider "aws" {
  region = "ap-southeast-2"
}

# Prod Account
provider "aws" {
  alias  = "prod"
  region = "ap-southeast-2"
}

# Pre-Prod Account
provider "aws" {
  alias  = "pre-prod"
  region = "ap-southeast-2"
}

# Staging Account
provider "aws" {
  alias  = "staging"
  region = "ap-southeast-2"
}

# Dev Account
provider "aws" {
  alias  = "dev"
  region = "ap-southeast-2"
}

data "aws_organizations_organization" "this" {}

locals {
  name = "terraform-aws-modules"

  organization_arn = data.aws_organizations_organization.this.arn
}

################################################################################
# Transit Gateway Module
################################################################################

module "transit_gateway" {
  source = "../../"

  name        = local.name
  description = "Network Service Transit Gateway"

  vpc_attachment_defaults = {
    transit_gateway_default_route_table_association = false
    transit_gateway_default_route_table_propagation = false
  }

  vpc_attachments = {
    # Create Network Service Attachment in the same account
    network-attachment-3 = {
      vpc_id     = module.network_vpc.vpc_id
      subnet_ids = module.network_vpc.private_subnets

      vpc_routes = {
        main = {
          route_table_ids         = module.network_vpc.private_route_table_ids
          destination_cidr_blocks = ["10.0.0.0/8"]
        }
      }
    },
    # The rest of the attachments are created with separate providers for each account
    # and the attachment request is accepted here
    prod-attachment-1 = {
      vpc_attachment_id        = module.prod_tgw_attachment.vpc_attachments["prod-attachment-1"].id
      accept_shared_attachment = true
    },
    pre-prod-attachment-2 = {
      vpc_attachment_id        = module.pre_prod_tgw_attachment.vpc_attachments["pre-prod-attachment-2"].id
      accept_shared_attachment = true
    },
    staging-attachment-5 = {
      vpc_attachment_id        = module.staging_tgw_attachment.vpc_attachments["staging-attachment-5"].id
      accept_shared_attachment = true
    },
    dev-attachment-6 = {
      vpc_attachment_id        = module.dev_tgw_attachment.vpc_attachments["dev-attachment-6"].id
      accept_shared_attachment = true
    },
  }
  # Reference VPN attachment to be used in the route tables
  attachments = {
    vpn-attachment-4 = {
      attachment_id = aws_vpn_connection.attachment_4.transit_gateway_attachment_id
    },
  }

  route_tables = {
    prod = {
      associations = ["prod-attachment-1", "pre-prod-attachment-2"]
      propagations = ["prod-attachment-1", "pre-prod-attachment-2"]
    }

    staging = {
      associations = ["staging-attachment-5", "dev-attachment-6"]
      propagations = ["staging-attachment-5", "dev-attachment-6"]
    }

    network-service = {
      associations = ["network-attachment-3", "vpn-attachment-4"]
      propagations = ["network-attachment-3"]

      static_routes = [
        { destination_cidr_block = "172.16.0.0/16", attachment = "vpn-attachment-4" }
      ]
    }
  }

  enable_ram_share = true
  ram_principals   = [local.organization_arn]
}

module "prod_tgw_attachment" {
  source = "../../"

  providers = {
    aws = aws.prod
  }

  name = local.name

  tgw_id     = module.transit_gateway.id
  create_tgw = false

  vpc_attachments = {
    prod-attachment-1 = {
      vpc_id     = module.prod_vpc.vpc_id
      subnet_ids = module.prod_vpc.private_subnets

      vpc_routes = {
        main = {
          route_table_ids         = module.prod_vpc.private_route_table_ids
          destination_cidr_blocks = ["10.0.0.0/8"]
        }
      }
    },
  }
}

module "pre_prod_tgw_attachment" {
  source = "../../"

  providers = {
    aws = aws.pre-prod
  }

  name = local.name

  tgw_id     = module.transit_gateway.id
  create_tgw = false

  vpc_attachments = {
    pre-prod-attachment-2 = {
      vpc_id     = module.pre_prod_vpc.vpc_id
      subnet_ids = module.pre_prod_vpc.private_subnets

      vpc_routes = {
        main = {
          route_table_ids         = module.pre_prod_vpc.private_route_table_ids
          destination_cidr_blocks = ["10.0.0.0/8"]
        }
      }
    },
  }
}

module "staging_tgw_attachment" {
  source = "../../"

  providers = {
    aws = aws.staging
  }

  name = local.name

  tgw_id     = module.transit_gateway.id
  create_tgw = false

  vpc_attachments = {
    staging-attachment-5 = {
      vpc_id     = module.staging_vpc.vpc_id
      subnet_ids = module.staging_vpc.private_subnets

      vpc_routes = {
        main = {
          route_table_ids         = module.staging_vpc.private_route_table_ids
          destination_cidr_blocks = ["10.0.0.0/8"]
        }
      }
    },
  }
}

module "dev_tgw_attachment" {
  source = "../../"

  providers = {
    aws = aws.dev
  }

  name = local.name

  tgw_id     = module.transit_gateway.id
  create_tgw = false

  vpc_attachments = {
    dev-attachment-6 = {
      vpc_id     = module.dev_vpc.vpc_id
      subnet_ids = module.dev_vpc.private_subnets

      vpc_routes = {
        main = {
          route_table_ids         = module.dev_vpc.private_route_table_ids
          destination_cidr_blocks = ["10.0.0.0/8"]
        }
      }
    },
  }
}

################################################################################
# Supporting resources
################################################################################

locals {
  prod_vpc_cidr     = "10.1.0.0/16"
  pre_prod_vpc_cidr = "10.2.0.0/16"
  network_vpc_cidr  = "10.3.0.0/16"
  staging_vpc_cidr  = "10.4.0.0/16"
  dev_vpc_cidr      = "10.5.0.0/16"

  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

data "aws_availability_zones" "available" {
  # Exclude local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

module "prod_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.prod
  }

  name = "prod"
  cidr = local.prod_vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.prod_vpc_cidr, 4, k)]
}

module "pre_prod_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.pre-prod
  }

  name = "pre_prod"
  cidr = local.pre_prod_vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.pre_prod_vpc_cidr, 4, k)]
}

module "network_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "network"
  cidr = local.network_vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.network_vpc_cidr, 4, k)]
}

module "staging_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.staging
  }

  name = "staging"
  cidr = local.staging_vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.staging_vpc_cidr, 4, k)]
}

module "dev_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.dev
  }

  name = "dev"
  cidr = local.dev_vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.dev_vpc_cidr, 4, k)]
}

resource "aws_customer_gateway" "vpn" {
  bgp_asn    = 65000
  ip_address = "172.0.0.1"
  type       = "ipsec.1"
}

resource "aws_vpn_connection" "attachment_4" {
  customer_gateway_id = aws_customer_gateway.vpn.id
  transit_gateway_id  = module.transit_gateway.id
  type                = aws_customer_gateway.vpn.type

  tags = {
    Name = "${local.name}-vpn-attachment-4"
  }
}
