variable "create" {
  description = "Controls if resources should be created (it affects almost all resources)"
  type        = bool
  default     = true
}

variable "name" {
  description = "Name to be used on all the resources as the identifier"
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

################################################################################
# Transit Gateway
################################################################################

variable "create_tgw" {
  description = "Controls if the Transit Gateway resource should be created"
  type        = bool
  default     = true
}

variable "tgw_id" {
  description = "Id of the Transit Gateway to use for attachments and route tables when create_tgw = true"
  type        = string
  default     = ""
}

variable "description" {
  description = "Description of the EC2 Transit Gateway"
  type        = string
  default     = null
}

variable "amazon_side_asn" {
  description = "The Autonomous System Number (ASN) for the Amazon side of the gateway. By default the TGW is created with the current default Amazon ASN"
  type        = string
  default     = null
}

variable "auto_accept_shared_attachments" {
  description = "Whether resource attachment requests are automatically accepted"
  type        = bool
  default     = false
}

variable "default_route_table_association" {
  description = "Whether resource attachments are automatically associated with the default association route table"
  type        = bool
  default     = false
}

variable "default_route_table_propagation" {
  description = "Whether resource attachments automatically propagate routes to the default propagation route table"
  type        = bool
  default     = false
}

variable "dns_support" {
  description = "Should be true to enable DNS support in the TGW"
  type        = bool
  default     = true
}

variable "multicast_support" {
  description = "Whether multicast support is enabled"
  type        = bool
  default     = false
}

variable "security_group_referencing_support" {
  description = "Whether security group referencing is enabled"
  type        = bool
  default     = false
}

variable "transit_gateway_cidr_blocks" {
  description = "One or more IPv4 or IPv6 CIDR blocks for the transit gateway. Must be a size /24 CIDR block or larger for IPv4, or a size /64 CIDR block or larger for IPv6"
  type        = list(string)
  default     = []
}

variable "vpn_ecmp_support" {
  description = "Whether VPN Equal Cost Multipath Protocol support is enabled"
  type        = bool
  default     = true
}

variable "timeouts" {
  description = "Create, update, and delete timeout configurations for the transit gateway"
  type        = map(string)
  default     = {}
}

variable "tgw_tags" {
  description = "Additional tags for the TGW"
  type        = map(string)
  default     = {}
}

################################################################################
# Attachments
################################################################################

variable "vpc_attachment_defaults" {
  description = "Map of VPC route table attachments to create"
  type = any
  default = {}
}

variable "vpc_attachments" {
  description = "Map of VPC route table attachments to create"
  type = map(object({
    subnet_ids                                      = optional(list(string))
    vpc_id                                          = optional(string)
    
    dns_support                                     = optional(bool)
    ipv6_support                                    = optional(bool)
    appliance_mode_support                          = optional(bool)
    security_group_referencing_support              = optional(bool)
    transit_gateway_default_route_table_association = optional(bool)
    transit_gateway_default_route_table_propagation = optional(bool)

    create_attachment = optional(bool, true)
    accept_shared_attachment = optional(bool, false)
    vpc_attachment_id = optional(string)

    create_vpc_routes = optional(bool)
    # # Create routes using a list
    # vpc_routes_route_table_ids = optional(list(string), [])
    # vpc_routes_destination_cidr_blocks = ptional(list(string), [])
    # vpc_routes_destination_ipv6_cidr_blocks = optional(list(string), [])
    # # Create routes using a map
    # vpc_routes_defaults = optional(object({
    #   destination_cidr_blocks = optional(list(string), [])
    #   destination_ipv6_cidr_blocks = optional(list(string), [])
    # }))
    vpc_routes = optional(map(object({
      route_table_ids = list(string)
      destination_cidr_blocks = optional(list(string), [])
      destination_ipv6_cidr_blocks = optional(list(string), [])
    })), {})

    tags = optional(map(string), {})
  }))
  default = {}
}

variable "peering_attachments" {
  description = "Map of Transit Gateway peering attachments to create"
  type = map(object({
    peer_account_id         = optional(string)
    peer_region             = optional(string)
    peer_transit_gateway_id = optional(string)
    tags                    = optional(map(string), {})

    create_attachment = optional(bool, true)
    accept_peering_attachment = optional(bool, false)
    peering_attachment_id = optional(string)
  }))
  default = {}
}

variable "attachments" {
  description = "Map of Transit Gateway attachments to reference in the module (all attachment types)"
  type = map(object({
    attachment_id = string
  }))
  default = {}
}

################################################################################
# Transit Gateway Route Tables
################################################################################

variable "route_tables" {
  description = "Map of Transit Gateway route tables to create"
  type = any
  # type = map(object({
  #   attachments = optional(map(object({
  #     transit_gateway_attachment_id = optional(string)
  #     create_propagation            = optional(bool)
  #     create_association            = optional(bool)
  #     replace_existing_association  = optional(bool)
  #   })), {})
  #   static_routes = optional(map(object({
  #     destination_cidr_block        = optional(string)
  #     blackhole                     = optional(bool)
  #     transit_gateway_attachment_id = optional(string)
  #   })), {})
  #   tags = optional(map(string))
  # }))
  default = []
}

################################################################################
# Resource Access Manager
################################################################################

variable "enable_ram_share" {
  description = "Whether to share your transit gateway with other accounts"
  type        = bool
  default     = false
}

variable "ram_name" {
  description = "The name of the resource share of TGW"
  type        = string
  default     = ""
}

variable "ram_allow_external_principals" {
  description = "Indicates whether principals outside your organization can be associated with a resource share"
  type        = bool
  default     = false
}

variable "ram_principals" {
  description = "A list of principals to share TGW with. Possible values are an AWS account ID, an AWS Organizations Organization ARN, or an AWS Organizations Organization Unit ARN"
  type        = set(string)
  default     = []
}

variable "ram_tags" {
  description = "Additional tags for the RAM"
  type        = map(string)
  default     = {}
}

################################################################################
# Flow Logs
################################################################################

variable "create_flow_log" {
  description = "Whether to create flow log resource(s)"
  type        = bool
  default     = true
}

variable "flow_logs" {
  description = "Flow Logs to create for Transit Gateway or attachments"
  type = map(object({
    deliver_cross_account_role = optional(string)
    destination_options = optional(object({
      file_format                = optional(string, "parquet")
      hive_compatible_partitions = optional(bool, false)
      per_hour_partition         = optional(bool, true)
    }))
    iam_role_arn             = optional(string)
    log_destination          = optional(string)
    log_destination_type     = optional(string)
    log_format               = optional(string)
    max_aggregation_interval = optional(number, 30)
    traffic_type             = optional(string, "ALL")
    tags                     = optional(map(string), {})

    enable_transit_gateway = optional(bool, true)
    # The following can be provided when `enable_transit_gateway` is `false`
    vpc_attachment_key     = optional(string)
    peering_attachment_key = optional(string)
  }))
  default = {}
}
