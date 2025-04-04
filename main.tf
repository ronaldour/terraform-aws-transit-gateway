################################################################################
# Transit Gateway
################################################################################

locals {
  tgw_tags = merge(
    var.tags,
    { Name = var.name },
    var.tgw_tags,
  )

  transit_gateway_id = try(aws_ec2_transit_gateway.this[0].id, var.tgw_id)

  vpc_routes = flatten([
    for k, v in var.vpc_attachments : [
      for k1, v1 in v.vpc_routes : [
        for i, rtb_id in v1.route_table_ids : concat([
          for cidr in try(v1.destination_cidr_blocks, []) : {
            name                   = "${k}-${k1}-${cidr}-${i}" # <attachment>-<route>-<cidr>-<rtb-index>
            route_table_id         = rtb_id
            destination_cidr_block = cidr
            create                 = try(v.create_vpc_routes, true)
          }
          ], [
          for cidr in try(v1.destination_ipv6_cidr_blocks, []) : {
            name                        = "${k}-${k1}-${cidr}-${i}"
            route_table_id              = rtb_id
            destination_ipv6_cidr_block = cidr
            create                      = try(v.create_vpc_routes, true)
          }
        ])
      ]
    ]
  ])

  attachments = merge([
    { for k, v in aws_ec2_transit_gateway_vpc_attachment.this : k => { id = v.id } },
    { for k, v in aws_ec2_transit_gateway_vpc_attachment_accepter.this : k => { id = v.transit_gateway_attachment_id } },
    { for k, v in data.aws_ec2_transit_gateway_vpc_attachment.this : k => { id = v.id } },
    { for k, v in aws_ec2_transit_gateway_peering_attachment.this : k => { id = v.id } },
    { for k, v in aws_ec2_transit_gateway_peering_attachment_accepter.this : k => { id = v.transit_gateway_attachment_id } },
    { for k, v in data.aws_ec2_transit_gateway_peering_attachment.this : k => { id = v.id } },
    { for k, v in var.attachments : k => { id = v.attachment_id } },
  ]...)
}

resource "aws_ec2_transit_gateway" "this" {
  count = var.create && var.create_tgw ? 1 : 0

  amazon_side_asn                    = var.amazon_side_asn
  auto_accept_shared_attachments     = var.auto_accept_shared_attachments ? "enable" : "disable"
  default_route_table_association    = var.default_route_table_association ? "enable" : "disable"
  default_route_table_propagation    = var.default_route_table_propagation ? "enable" : "disable"
  description                        = var.description
  dns_support                        = var.dns_support ? "enable" : "disable"
  multicast_support                  = var.multicast_support ? "enable" : "disable"
  security_group_referencing_support = var.security_group_referencing_support ? "enable" : "disable"
  transit_gateway_cidr_blocks        = var.transit_gateway_cidr_blocks
  vpn_ecmp_support                   = var.vpn_ecmp_support ? "enable" : "disable"

  timeouts {
    create = try(var.timeouts.create, null)
    update = try(var.timeouts.update, null)
    delete = try(var.timeouts.delete, null)
  }

  tags = local.tgw_tags
}

resource "aws_ec2_tag" "this" {
  for_each = { for k, v in local.tgw_tags : k => v if var.create && var.create_tgw && var.default_route_table_association }

  resource_id = aws_ec2_transit_gateway.this[0].association_default_route_table_id
  key         = each.key
  value       = each.value
}

################################################################################
# VPC Attachment
################################################################################

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  for_each = { for k, v in var.vpc_attachments : k => v if var.create && try(v.create_attachment, true) && !try(v.accept_shared_attachment, false) }

  transit_gateway_id = local.transit_gateway_id

  vpc_id     = each.value.vpc_id
  subnet_ids = each.value.subnet_ids

  dns_support                        = coalesce(each.value.dns_support, var.vpc_attachment_defaults.dns_support, true) ? "enable" : "disable"
  ipv6_support                       = coalesce(each.value.ipv6_support, var.vpc_attachment_defaults.ipv6_support, false) ? "enable" : "disable"
  appliance_mode_support             = coalesce(each.value.appliance_mode_support, var.vpc_attachment_defaults.appliance_mode_support, false) ? "enable" : "disable"
  security_group_referencing_support = coalesce(each.value.security_group_referencing_support, var.vpc_attachment_defaults.security_group_referencing_support, false) ? "enable" : "disable"

  transit_gateway_default_route_table_association = try(coalesce(each.value.transit_gateway_default_route_table_association, var.vpc_attachment_defaults.transit_gateway_default_route_table_association), null)
  transit_gateway_default_route_table_propagation = try(coalesce(each.value.transit_gateway_default_route_table_propagation, var.vpc_attachment_defaults.transit_gateway_default_route_table_propagation), null)

  tags = merge(
    var.tags,
    { Name = "${var.name}-${each.key}" },
    try(each.value.tags, {}),
  )
}

resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "this" {
  for_each = { for k, v in var.vpc_attachments : k => v if var.create && v.accept_shared_attachment }

  transit_gateway_attachment_id                   = each.value.vpc_attachment_id
  transit_gateway_default_route_table_association = try(coalesce(each.value.transit_gateway_default_route_table_association, var.vpc_attachment_defaults.transit_gateway_default_route_table_association), null)
  transit_gateway_default_route_table_propagation = try(coalesce(each.value.transit_gateway_default_route_table_propagation, var.vpc_attachment_defaults.transit_gateway_default_route_table_propagation), null)

  tags = merge(
    var.tags,
    { Name = "${var.name}-${each.key}" },
    try(each.value.tags, {}),
  )
}

# Data source for existing attachments
data "aws_ec2_transit_gateway_vpc_attachment" "this" {
  for_each = { for k, v in var.vpc_attachments : k => v if var.create && !v.create_attachment && !v.accept_shared_attachment }

  id = each.value.vpc_attachment_id
}

# This sleep resource is used to provide a timed gap between a shared attachment creation and downstream dependencies.
# When a VPC attachment is created using a shared Transit Gateway, the owner has to accept the attachment first,
# this is a workaround to ensure the attachment is accepted before using it in TGW Route Tables and VPC Routes.
resource "time_sleep" "vpc_attachments" {
  create_duration = var.shared_attachment_wait_duration

  triggers = {
    # Create a hash of all attachment IDs to ensure we wait for all attachments
    attachments = join(",", [for k, v in aws_ec2_transit_gateway_vpc_attachment.this : v.id])
  }
}

resource "aws_route" "this" {
  for_each = { for k, v in local.vpc_routes : v.name => v if var.create && v.create }

  route_table_id              = each.value.route_table_id
  destination_cidr_block      = try(each.value.destination_cidr_block, null)
  destination_ipv6_cidr_block = try(each.value.destination_ipv6_cidr_block, null)
  transit_gateway_id          = local.transit_gateway_id

  depends_on = [time_sleep.vpc_attachments]
}


################################################################################
# TGW Peering Attachment
################################################################################

resource "aws_ec2_transit_gateway_peering_attachment" "this" {
  for_each = { for k, v in var.peering_attachments : k => v if var.create && !v.accept_peering_attachment }

  peer_account_id         = each.value.peer_account_id
  peer_region             = each.value.peer_region
  peer_transit_gateway_id = each.value.peer_transit_gateway_id
  transit_gateway_id      = local.transit_gateway_id

  tags = merge(
    var.tags,
    { Name = "${var.name}-${each.key}" },
    try(each.value.tags, {}),
  )
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "this" {
  for_each = { for k, v in var.peering_attachments : k => v if var.create && v.accept_peering_attachment }

  transit_gateway_attachment_id = each.value.peering_attachment_id

  tags = merge(
    var.tags,
    { Name = "${var.name}-${each.key}" },
    try(each.value.tags, {}),
  )
}

# Data source for existing peering attachments
data "aws_ec2_transit_gateway_peering_attachment" "this" {
  for_each = { for k, v in var.peering_attachments : k => v if var.create && !v.create_attachment && !v.accept_peering_attachment }

  id = each.value.peering_attachment_id
}

# This sleep resource is used to provide a timed gap between a peering attachment creation and downstream dependencies.
# Peering attachments need to be accepted first before Transit Gateway Routes and Associations can be created.
resource "time_sleep" "peering_attachments" {
  create_duration = var.shared_attachment_wait_duration

  triggers = {
    # Create a hash of all attachment IDs to ensure we wait for all attachments
    attachments = join(",", concat([for k, v in aws_ec2_transit_gateway_peering_attachment.this : v.id]))
  }
}

################################################################################
# Transit Gateway Route Tables
################################################################################

module "management_transit_gateway_route_table" {
  source = "./modules/route-table"

  for_each = { for k, v in var.route_tables : k => v if var.create }

  name               = each.key
  transit_gateway_id = local.transit_gateway_id

  associations = { for a in try(each.value.associations, {}) : a => { transit_gateway_attachment_id = local.attachments[a].id, replace_existing_association = true } }

  propagations = { for p in try(each.value.propagations, {}) : p => local.attachments[p].id }

  static_routes = { for route in try(each.value.static_routes, []) : route.destination_cidr_block => {
    destination_cidr_block        = route.destination_cidr_block
    blackhole                     = try(route.blackhole, null)
    transit_gateway_attachment_id = try(local.attachments[route.attachment].id, route.transit_gateway_attachment_id, null)
  } }

  depends_on = [time_sleep.vpc_attachments, time_sleep.peering_attachments]
}

################################################################################
# Resource Access Manager
################################################################################

locals {
  ram_name = try(coalesce(var.ram_name, var.name), "")
}

resource "aws_ram_resource_share" "this" {
  count = var.create && var.enable_ram_share ? 1 : 0

  name                      = local.ram_name
  allow_external_principals = var.ram_allow_external_principals

  tags = merge(
    var.tags,
    { Name = local.ram_name },
    var.ram_tags,
  )
}

resource "aws_ram_resource_association" "this" {
  count = var.create && var.enable_ram_share ? 1 : 0

  resource_arn       = aws_ec2_transit_gateway.this[0].arn
  resource_share_arn = aws_ram_resource_share.this[0].id
}

resource "aws_ram_principal_association" "this" {
  for_each = { for k, v in var.ram_principals : k => v if var.create && var.enable_ram_share }

  principal          = each.value
  resource_share_arn = aws_ram_resource_share.this[0].arn
}

################################################################################
# Flow Log(s)
################################################################################

resource "aws_flow_log" "this" {
  for_each = { for k, v in var.flow_logs : k => v if var.create && var.create_flow_log }

  deliver_cross_account_role = each.value.deliver_cross_account_role

  dynamic "destination_options" {
    for_each = each.value.destination_options != null ? [each.value.destination_options] : []

    content {
      file_format                = destination_options.value.file_format
      hive_compatible_partitions = destination_options.value.hive_compatible_partitions
      per_hour_partition         = destination_options.value.per_hour_partition
    }
  }

  iam_role_arn             = each.value.iam_role_arn
  log_destination          = each.value.log_destination
  log_destination_type     = each.value.log_destination_type
  log_format               = each.value.log_format
  max_aggregation_interval = max(each.value.max_aggregation_interval, 60)

  traffic_type       = each.value.traffic_type
  transit_gateway_id = each.value.enable_transit_gateway ? local.transit_gateway_id : null
  transit_gateway_attachment_id = each.value.enable_transit_gateway ? null : try(
    aws_ec2_transit_gateway_vpc_attachment.this[each.value.vpc_attachment_key].id,
    aws_ec2_transit_gateway_peering_attachment.this[each.value.peering_attachment_key].id,
    null
  )

  tags = merge(
    var.tags,
    each.value.tags,
  )
}
