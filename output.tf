// aws_ec2_transit_gateway
output "this_ec2_transit_gateway_arn" {
  description = "EC2 Transit Gateway Amazon Resource Name (ARN)"
  value       = element(concat(aws_ec2_transit_gateway.this.*.arn, [""]), 0)
}

output "this_ec2_transit_gateway_association_default_route_table_id" {
  description = "Identifier of the default association route table"
  value       = element(concat(aws_ec2_transit_gateway.this.*.association_default_route_table_id, [""]), 0)
}

output "this_ec2_transit_gateway_id" {
  description = "EC2 Transit Gateway identifier"
  value       = element(concat(aws_ec2_transit_gateway.this.*.id, [""]), 0)
}

output "this_ec2_transit_gateway_owner_id" {
  description = "Identifier of the AWS account that owns the EC2 Transit Gateway"
  value       = element(concat(aws_ec2_transit_gateway.this.*.owner_id, [""]), 0)
}

output "this_ec2_transit_gateway_propagation_default_route_table_id" {
  description = "Identifier of the default propagation route table"
  value       = element(concat(aws_ec2_transit_gateway.this.*.propagation_default_route_table_id, [""]), 0)
}
// aws_ec2_transit_gateway_route_table
output "this_ec2_transit_gateway_route_tables" {
  description = "Map of the created route tables"
  value       = { for k, t in aws_ec2_transit_gateway_route_table.this : t.tags.Name => t.id }
}
// aws_ec2_transit_gateway_vpc_attachment

locals {
  vpcs_map = { for v in var.vpcs : v["vpc_id"] => v }

}

output "this_ec2_transit_gateway_vpcs_attributed" {
  description = "List of EC2 Transit Gateway VPC Attachment identifiers"
  value       = [for k, v in aws_ec2_transit_gateway_vpc_attachment.this : merge(local.vpcs_map[k], { ec2_transit_gateway_vpc_attachment_id : v.id })]
}

output "this_ec2_transit_gateway_vpc_attachment_ids" {
  description = "Mapped VPC's to attachment id's"
  value       = zipmap([for k, v in aws_ec2_transit_gateway_vpc_attachment.this : k], [for k, v in aws_ec2_transit_gateway_vpc_attachment.this : v.id])
}

output "this_ec2_transit_gateway_vpc_attachment" {
  description = "Map of EC2 Transit Gateway VPC Attachment attributes"
  value       = aws_ec2_transit_gateway_vpc_attachment.this
}
