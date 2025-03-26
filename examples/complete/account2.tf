provider "aws" {
  alias  = "account2"
  region = local.peer_region
}

module "vpc5" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.account2
  }

  name = "${local.name}-vpc5"
  cidr = local.vpc5_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs_peer : cidrsubnet(local.vpc5_cidr, 4, k)]

  tags = local.tags
}

module "transit_gateway_attachment" {
  source = "../../"

  providers = {
    aws = aws.account2
  }

  name = local.name

  create_tgw = false
  tgw_id     = module.transit_gateway_peer.id

  vpc_attachments = {

    vpc5 = {
      vpc_id                             = module.vpc5.vpc_id
      subnet_ids                         = module.vpc5.private_subnets
      security_group_referencing_support = true

      # The routes can't be created until the attachment request is accepted in the transit gateway account.
      # This can be a problem if creating this attachment in a separate terraform. Consider using the 
      # create_vpc_routes flag and apply in two phases.
      create_vpc_routes = true
      vpc_routes = {
        tgw_route = {
          route_table_ids         = module.vpc5.private_route_table_ids
          destination_cidr_blocks = ["10.0.0.0/8"]
        }
      }
    }
  }
}