resource "aws_ec2_transit_gateway" "this" {
  count = var.create ? 1 : 0

  description                     = coalesce(var.description, var.name)
  amazon_side_asn                 = var.amazon_side_asn
  default_route_table_association = var.enable_default_route_table_association ? "enable" : "disable"
  default_route_table_propagation = var.enable_default_route_table_propagation ? "enable" : "disable"
  auto_accept_shared_attachments  = var.enable_auto_accept_shared_attachments ? "enable" : "disable"
  vpn_ecmp_support                = var.enable_vpn_ecmp_support ? "enable" : "disable"
  dns_support                     = var.enable_dns_support ? "enable" : "disable"

  tags = merge(
    {
      "Name" = format("%s", var.name)
    },
    var.tags,
    var.tgw_tags,
  )
}

#########################
# Route table and routes
#########################
locals {
  transit_gateway_route_tables = compact(distinct(flatten(
    [for v in var.vpcs : [v["propagated_in_route_tables"], v["associated_with_route_table"]]]
  )))
}

resource "aws_ec2_transit_gateway_route_table" "this" {
  for_each = { for v in local.transit_gateway_route_tables : v => v if var.create && v != local.default_table }

  transit_gateway_id = join("", aws_ec2_transit_gateway.this.*.id)

  tags = merge(
    {
      "Name" = format("%s", each.key)
    },
    var.tags,
    var.tgw_route_table_tags,
  )
}
###########################################################
# VPC Attachments, route table association and propagation
###########################################################
resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  for_each = { for v in var.vpcs : v["vpc_id"] => v if var.create }

  transit_gateway_id = join("", aws_ec2_transit_gateway.this.*.id)
  vpc_id             = each.value["vpc_id"]
  subnet_ids         = each.value["subnet_ids"]

  dns_support                                     = lookup(each.value, "dns_support", true) ? "enable" : "disable"
  ipv6_support                                    = lookup(each.value, "ipv6_support", false) ? "enable" : "disable"
  transit_gateway_default_route_table_association = lookup(each.value, "transit_gateway_default_route_table_association", false)
  transit_gateway_default_route_table_propagation = lookup(each.value, "transit_gateway_default_route_table_propagation", false)

  tags = merge(
    {
      Name = format("%s-%s", var.name, each.key)
    },
    var.tags,
    var.tgw_vpc_attachment_tags,
  )
}

locals {
  table_lookup = merge(
    { for k, t in aws_ec2_transit_gateway_route_table.this : t.tags.Name => t.id },
  map(local.default_table, concat(aws_ec2_transit_gateway.this.*.association_default_route_table_id, [""])[0]))

  attachment_lookup = { for k, v in aws_ec2_transit_gateway_vpc_attachment.this : k => v["id"] }

  transit_gateway_route_table_associations = flatten([for v in var.vpcs :
    {
      vpc_id                      = v["vpc_id"]
      associated_with_route_table = v["associated_with_route_table"]
    }
  ])

  transit_gateway_route_table_propagations = flatten([for v in var.vpcs :
    {
      vpc_id                     = v["vpc_id"]
      propagated_in_route_tables = v["propagated_in_route_tables"]
    }
  ])
}

locals {
  routes_flattened = flatten([
    for k, v in var.routes : [
      for rid in v["propagated_in_route_tables"] : {
        vpc_id                    = v["vpc_id"]
        destination_cidr_block    = v["destination_cidr_block"]
        blackhole                 = lookup(v, "blackhole", false)
        propagated_in_route_table = rid
      }
  ]])
}

// VPC attachment routes
resource "aws_ec2_transit_gateway_route" "this" {
  for_each = { for r in local.routes_flattened: "${r["propagated_in_route_table"]}-${r["destination_cidr_block"]}-${r["vpc_id"]}" => r if var.create }

  destination_cidr_block = each.value["destination_cidr_block"]
  blackhole              = each.value["blackhole"]

  transit_gateway_route_table_id = lookup(local.table_lookup, each.value["propagated_in_route_table"])
  transit_gateway_attachment_id  = lookup(local.attachment_lookup, each.value["vpc_id"])
}


# Every route table can only have a single association
resource "aws_ec2_transit_gateway_route_table_association" "this" {
  for_each = { for a in local.transit_gateway_route_table_associations : "${a["associated_with_route_table"]}-${a["vpc_id"]}" => a if var.create }

  // Create association if it was not set already by aws_ec2_transit_gateway_vpc_attachment resource
  transit_gateway_route_table_id = lookup(local.table_lookup, each.value["associated_with_route_table"])
  transit_gateway_attachment_id  = lookup(local.attachment_lookup, each.value["vpc_id"])
}

locals {
  transit_gateway_route_table_propagations_flattened = flatten([
    for k, v in local.transit_gateway_route_table_propagations : [
      for rid in v["propagated_in_route_tables"] : {
        vpc_id                    = v["vpc_id"]
        propagated_in_route_table = rid
      } if rid != local.default_table
  ]])
}

resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  for_each = { for p in local.transit_gateway_route_table_propagations_flattened : "${p["propagated_in_route_table"]}-${p["vpc_id"]}" => p if var.create }

  transit_gateway_route_table_id = lookup(local.table_lookup, each.value["propagated_in_route_table"])
  transit_gateway_attachment_id  = lookup(local.attachment_lookup, each.value["vpc_id"])
}
