# Complete AWS Transit Gateway example

This example showcases the architecture presented in the AWS Architecture Blog post [Field Notes: Working with Route Tables in AWS Transit Gateway](https://aws.amazon.com/blogs/architecture/field-notes-working-with-route-tables-in-aws-transit-gateway/).

![architecture-diagram](https://d2908q01vomqb2.cloudfront.net/fc074d501302eb2b93e2554793fcaf50b3bf7291/2020/08/07/How-different-AWS-accounts-are-connected-via-AWS-Transit-Gateway.png)

## Usage

To run this example you need to execute:

```bash
$ terraform init
$ terraform plan
$ terraform apply
```

Note that this example may create resources which cost money. Run `terraform destroy` when you don't need these resources.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.78 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.78 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_dev_tgw_attachment"></a> [dev\_tgw\_attachment](#module\_dev\_tgw\_attachment) | ../../ | n/a |
| <a name="module_dev_vpc"></a> [dev\_vpc](#module\_dev\_vpc) | terraform-aws-modules/vpc/aws | ~> 5.0 |
| <a name="module_network_vpc"></a> [network\_vpc](#module\_network\_vpc) | terraform-aws-modules/vpc/aws | ~> 5.0 |
| <a name="module_pre_prod_tgw_attachment"></a> [pre\_prod\_tgw\_attachment](#module\_pre\_prod\_tgw\_attachment) | ../../ | n/a |
| <a name="module_pre_prod_vpc"></a> [pre\_prod\_vpc](#module\_pre\_prod\_vpc) | terraform-aws-modules/vpc/aws | ~> 5.0 |
| <a name="module_prod_tgw_attachment"></a> [prod\_tgw\_attachment](#module\_prod\_tgw\_attachment) | ../../ | n/a |
| <a name="module_prod_vpc"></a> [prod\_vpc](#module\_prod\_vpc) | terraform-aws-modules/vpc/aws | ~> 5.0 |
| <a name="module_staging_tgw_attachment"></a> [staging\_tgw\_attachment](#module\_staging\_tgw\_attachment) | ../../ | n/a |
| <a name="module_staging_vpc"></a> [staging\_vpc](#module\_staging\_vpc) | terraform-aws-modules/vpc/aws | ~> 5.0 |
| <a name="module_transit_gateway"></a> [transit\_gateway](#module\_transit\_gateway) | ../../ | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_customer_gateway.vpn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/customer_gateway) | resource |
| [aws_vpn_connection.attachment_4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpn_connection) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_organizations_organization.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/organizations_organization) | data source |

## Inputs

No inputs.

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
