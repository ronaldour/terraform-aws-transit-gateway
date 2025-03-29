# AWS Transit Gateway Terraform module

Terraform module which creates AWS Transit Gateway resources.

[![SWUbanner](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/banner2-direct.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)

## Usage

### Create Transit Gateway

```hcl
module "transit_gateway" {
  source  = "terraform-aws-modules/transit-gateway/aws"

  name        = "example"
  description = "Example TGW connecting multiple VPCs"

  amazon_side_asn = 64512

  security_group_referencing_support = true

  default_route_table_association = false
  default_route_table_propagation = false

  # When `true` there is no need for RAM resources if using multiple AWS accounts
  auto_accept_shared_attachments = false

  enable_ram_share = true
  ram_principals   = var.transit_gateway_ram_principals

  tags = {
    Environment = "Development"
    Project     = "Example"
  }
}
```

### Managing Transit Gateway Attachments

The module can be used in three different ways to manage attachments.
1. Create attachments
2. Accept shared attachments
3. Reference existing attachments in other parts of the module

_Note: currently the module only supports VPC attachments and Peering attachments._

```hcl
module "transit_gateway" {
  source  = "terraform-aws-modules/transit-gateway/aws"

  name = "example"

  vpc_attachments = {
    # Create VPC attachment
    vpc1 = {
      vpc_id     = module.vpc1.vpc_id
      subnet_ids = module.vpc1.private_subnets
    }
    # Accept shared VPC attachment
    vpc2 = {
      accept_shared_attachment = true
      vpc_attachment_id = "tgw-attach-0fa87d9be79f4eaf7"
    }
    # Reference existing VPC attachment
    vpc3 = {
      create_attachment = false
      vpc_attachment_id = "tgw-attach-0d339a151e8aa6eb4"
    }
  }

  peering_attachments = {
    # Create peering attachment
    west = {
      peer_region             = "us-west-2"
      peer_account_id         = module.transit_gateway_west.owner_id
      peer_transit_gateway_id = module.transit_gateway_west.id
    }
    # Accept shared peering attachment
    east = {
      accept_shared_attachment = true
      transit_gateway_attachment_id = module.transit_gateway.peering_attachments["east"].id
    }
    # Reference existing peering attachment
    ap = {
      create_attachment = false
      transit_gateway_attachment_id = "tgw-attach-1e8aa6eb40d339a15"
    }
  }
}
```

The VPC attachments also have an additional feature to create VPC Routes to the Trasint Gateway:

```hcl
  vpc_attachments = {
    # Create VPC attachment
    vpc1 = {
      vpc_id     = module.vpc1.vpc_id
      subnet_ids = module.vpc1.private_subnets

      vpc_routes = {
        route1 = {
          route_table_ids = module.vpc1.private_route_table_ids
          destination_cidr_blocks = ["10.0.0.0/8"]
        }
      }
    }
  }
```

_Note: Internally the module uses the index of the route_table_ids list, which can lead to recreating routes if the order of the elements change, to avoid this use a single route_table_id per route object._



### Managing Transit Gateway Route Tables and Routes

The module uses the [route-table](./modules/route-table/) sub-module to create Transig Gateway route tables and routes using the attachment friendly names defined in the attachments sections.

```hcl
module "transit_gateway" {
  source  = "terraform-aws-modules/transit-gateway/aws"

  name = "example"

  # Attachments truncated for brevity ...

  route_tables = {
    rtb1 = {
      associations = [ "vpc1", "west" ]
      propagations = [ "vpc1", "vpc2", "vpc3" ]

      static_routes = [
        { destination_cidr_block = "10.20.0.0/16", attachment = "east" },
        { destination_cidr_block = "10.30.0.0/16", attachment = "ap" },
      ]
    }
    rtb2 = {
      associations = [ "vpc2", "vpc3", "east", "ap" ]
      propagations = [ "vpc1" ]

      static_routes = [
        { destination_cidr_block = "10.10.0.0/16", attachment = "west" },
        { destination_cidr_block = "0.0.0.0/0", blackhole = true },
      ]
    }
  }
}
```

## Examples

- [Complete example](https://github.com/terraform-aws-modules/terraform-aws-transit-gateway/tree/master/examples/complete) shows a multi-account multi-region TGW setup in combination with the [VPC module](https://github.com/terraform-aws-modules/terraform-aws-vpc).
- [aws-blogpost example](https://github.com/terraform-aws-modules/terraform-aws-transit-gateway/tree/master/examples/aws-blogpost) shows the architecture presented in the AWS Architecture Blog post [Field Notes: Working with Route Tables in AWS Transit Gateway](https://aws.amazon.com/blogs/architecture/field-notes-working-with-route-tables-in-aws-transit-gateway/).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.78 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.78 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_management_transit_gateway_route_table"></a> [management\_transit\_gateway\_route\_table](#module\_management\_transit\_gateway\_route\_table) | ./modules/route-table | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_ec2_tag.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_ec2_transit_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway) | resource |
| [aws_ec2_transit_gateway_peering_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_peering_attachment) | resource |
| [aws_ec2_transit_gateway_peering_attachment_accepter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_peering_attachment_accepter) | resource |
| [aws_ec2_transit_gateway_vpc_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_vpc_attachment) | resource |
| [aws_ec2_transit_gateway_vpc_attachment_accepter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_vpc_attachment_accepter) | resource |
| [aws_flow_log.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_ram_principal_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_principal_association) | resource |
| [aws_ram_resource_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_association) | resource |
| [aws_ram_resource_share.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_share) | resource |
| [aws_route.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_ec2_transit_gateway_peering_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_transit_gateway_peering_attachment) | data source |
| [aws_ec2_transit_gateway_vpc_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_transit_gateway_vpc_attachment) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_amazon_side_asn"></a> [amazon\_side\_asn](#input\_amazon\_side\_asn) | The Autonomous System Number (ASN) for the Amazon side of the gateway. By default the TGW is created with the current default Amazon ASN | `string` | `null` | no |
| <a name="input_attachments"></a> [attachments](#input\_attachments) | Map of Transit Gateway attachments to reference in the module (all attachment types) | <pre>map(object({<br>    attachment_id = string<br>  }))</pre> | `{}` | no |
| <a name="input_auto_accept_shared_attachments"></a> [auto\_accept\_shared\_attachments](#input\_auto\_accept\_shared\_attachments) | Whether resource attachment requests are automatically accepted | `bool` | `false` | no |
| <a name="input_create"></a> [create](#input\_create) | Controls if resources should be created (it affects almost all resources) | `bool` | `true` | no |
| <a name="input_create_flow_log"></a> [create\_flow\_log](#input\_create\_flow\_log) | Whether to create flow log resource(s) | `bool` | `true` | no |
| <a name="input_create_tgw"></a> [create\_tgw](#input\_create\_tgw) | Controls if the Transit Gateway resource should be created | `bool` | `true` | no |
| <a name="input_default_route_table_association"></a> [default\_route\_table\_association](#input\_default\_route\_table\_association) | Whether resource attachments are automatically associated with the default association route table | `bool` | `false` | no |
| <a name="input_default_route_table_propagation"></a> [default\_route\_table\_propagation](#input\_default\_route\_table\_propagation) | Whether resource attachments automatically propagate routes to the default propagation route table | `bool` | `false` | no |
| <a name="input_description"></a> [description](#input\_description) | Description of the EC2 Transit Gateway | `string` | `null` | no |
| <a name="input_dns_support"></a> [dns\_support](#input\_dns\_support) | Should be true to enable DNS support in the TGW | `bool` | `true` | no |
| <a name="input_enable_ram_share"></a> [enable\_ram\_share](#input\_enable\_ram\_share) | Whether to share your transit gateway with other accounts | `bool` | `false` | no |
| <a name="input_flow_logs"></a> [flow\_logs](#input\_flow\_logs) | Flow Logs to create for Transit Gateway or attachments | <pre>map(object({<br>    deliver_cross_account_role = optional(string)<br>    destination_options = optional(object({<br>      file_format                = optional(string, "parquet")<br>      hive_compatible_partitions = optional(bool, false)<br>      per_hour_partition         = optional(bool, true)<br>    }))<br>    iam_role_arn             = optional(string)<br>    log_destination          = optional(string)<br>    log_destination_type     = optional(string)<br>    log_format               = optional(string)<br>    max_aggregation_interval = optional(number, 30)<br>    traffic_type             = optional(string, "ALL")<br>    tags                     = optional(map(string), {})<br><br>    enable_transit_gateway = optional(bool, true)<br>    # The following can be provided when `enable_transit_gateway` is `false`<br>    vpc_attachment_key     = optional(string)<br>    peering_attachment_key = optional(string)<br>  }))</pre> | `{}` | no |
| <a name="input_multicast_support"></a> [multicast\_support](#input\_multicast\_support) | Whether multicast support is enabled | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | Name to be used on all the resources as the identifier | `string` | `""` | no |
| <a name="input_peering_attachments"></a> [peering\_attachments](#input\_peering\_attachments) | Map of Transit Gateway peering attachments | <pre>map(object({<br>    peer_account_id         = optional(string)<br>    peer_region             = optional(string)<br>    peer_transit_gateway_id = optional(string)<br>    tags                    = optional(map(string), {})<br><br>    create_attachment         = optional(bool, true)<br>    accept_peering_attachment = optional(bool, false)<br>    peering_attachment_id     = optional(string)<br>  }))</pre> | `{}` | no |
| <a name="input_ram_allow_external_principals"></a> [ram\_allow\_external\_principals](#input\_ram\_allow\_external\_principals) | Indicates whether principals outside your organization can be associated with a resource share | `bool` | `false` | no |
| <a name="input_ram_name"></a> [ram\_name](#input\_ram\_name) | The name of the resource share of TGW | `string` | `""` | no |
| <a name="input_ram_principals"></a> [ram\_principals](#input\_ram\_principals) | A list of principals to share TGW with. Possible values are an AWS account ID, an AWS Organizations Organization ARN, or an AWS Organizations Organization Unit ARN | `set(string)` | `[]` | no |
| <a name="input_ram_tags"></a> [ram\_tags](#input\_ram\_tags) | Additional tags for the RAM | `map(string)` | `{}` | no |
| <a name="input_route_tables"></a> [route\_tables](#input\_route\_tables) | Map of Transit Gateway route tables to create | <pre>map(object({<br>    associations = optional(list(string), [])<br>    propagations = optional(list(string), [])<br>    static_routes = optional(list(object({<br>      destination_cidr_block = string<br>      attachment             = optional(string)<br>      blackhole              = optional(bool, false)<br>    })), [])<br>  }))</pre> | `{}` | no |
| <a name="input_security_group_referencing_support"></a> [security\_group\_referencing\_support](#input\_security\_group\_referencing\_support) | Whether security group referencing is enabled | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_tgw_id"></a> [tgw\_id](#input\_tgw\_id) | Id of the Transit Gateway to use for attachments and route tables when create\_tgw = true | `string` | `""` | no |
| <a name="input_tgw_tags"></a> [tgw\_tags](#input\_tgw\_tags) | Additional tags for the TGW | `map(string)` | `{}` | no |
| <a name="input_timeouts"></a> [timeouts](#input\_timeouts) | Create, update, and delete timeout configurations for the transit gateway | `map(string)` | `{}` | no |
| <a name="input_transit_gateway_cidr_blocks"></a> [transit\_gateway\_cidr\_blocks](#input\_transit\_gateway\_cidr\_blocks) | One or more IPv4 or IPv6 CIDR blocks for the transit gateway. Must be a size /24 CIDR block or larger for IPv4, or a size /64 CIDR block or larger for IPv6 | `list(string)` | `[]` | no |
| <a name="input_vpc_attachment_defaults"></a> [vpc\_attachment\_defaults](#input\_vpc\_attachment\_defaults) | Default configurations for Transit Gateway VPC attachments. The first non-null value will be used for each configuration with each attachment having precedence over the defaults | <pre>object({<br>    dns_support                                     = optional(bool)<br>    ipv6_support                                    = optional(bool)<br>    appliance_mode_support                          = optional(bool)<br>    security_group_referencing_support              = optional(bool)<br>    transit_gateway_default_route_table_association = optional(bool)<br>    transit_gateway_default_route_table_propagation = optional(bool)<br>  })</pre> | `{}` | no |
| <a name="input_vpc_attachments"></a> [vpc\_attachments](#input\_vpc\_attachments) | Map of Transit Gateway VPC attachments | <pre>map(object({<br>    subnet_ids = optional(list(string))<br>    vpc_id     = optional(string)<br><br>    dns_support                                     = optional(bool)<br>    ipv6_support                                    = optional(bool)<br>    appliance_mode_support                          = optional(bool)<br>    security_group_referencing_support              = optional(bool)<br>    transit_gateway_default_route_table_association = optional(bool)<br>    transit_gateway_default_route_table_propagation = optional(bool)<br><br>    create_attachment        = optional(bool, true)<br>    accept_shared_attachment = optional(bool, false)<br>    vpc_attachment_id        = optional(string)<br><br>    create_vpc_routes = optional(bool, true)<br>    vpc_routes = optional(map(object({<br>      route_table_ids              = list(string)<br>      destination_cidr_blocks      = optional(list(string), [])<br>      destination_ipv6_cidr_blocks = optional(list(string), [])<br>    })), {})<br><br>    tags = optional(map(string), {})<br>  }))</pre> | `{}` | no |
| <a name="input_vpn_ecmp_support"></a> [vpn\_ecmp\_support](#input\_vpn\_ecmp\_support) | Whether VPN Equal Cost Multipath Protocol support is enabled | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | EC2 Transit Gateway Amazon Resource Name (ARN) |
| <a name="output_association_default_route_table_id"></a> [association\_default\_route\_table\_id](#output\_association\_default\_route\_table\_id) | Identifier of the default association route table |
| <a name="output_id"></a> [id](#output\_id) | EC2 Transit Gateway identifier |
| <a name="output_owner_id"></a> [owner\_id](#output\_owner\_id) | Identifier of the AWS account that owns the EC2 Transit Gateway |
| <a name="output_peering_attachments"></a> [peering\_attachments](#output\_peering\_attachments) | Map of TGW peering attachments created |
| <a name="output_propagation_default_route_table_id"></a> [propagation\_default\_route\_table\_id](#output\_propagation\_default\_route\_table\_id) | Identifier of the default propagation route table |
| <a name="output_ram_resource_share_id"></a> [ram\_resource\_share\_id](#output\_ram\_resource\_share\_id) | The Amazon Resource Name (ARN) of the resource share |
| <a name="output_vpc_attachments"></a> [vpc\_attachments](#output\_vpc\_attachments) | Map of VPC attachments created |
<!-- END_TF_DOCS -->

## Authors

Module is maintained by [Anton Babenko](https://github.com/antonbabenko) with help from [these awesome contributors](https://github.com/terraform-aws-modules/terraform-aws-transit-gateway/graphs/contributors).

## License

Apache 2 Licensed. See [LICENSE](https://github.com/terraform-aws-modules/terraform-aws-transit-gateway/tree/master/LICENSE) for full details.
