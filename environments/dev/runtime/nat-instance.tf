module "nat_instance" {
  source = "../../../modules/nat-instance"

  name_prefix                   = local.name_prefix
  vpc_id                        = data.terraform_remote_state.foundation.outputs.vpc_id
  public_subnet_ids_by_az       = data.terraform_remote_state.foundation.outputs.public_subnet_ids_by_az
  private_route_table_ids_by_az = data.terraform_remote_state.foundation.outputs.private_route_table_ids_by_az
  private_subnet_cidrs          = toset(data.terraform_remote_state.foundation.outputs.private_subnet_cidrs)
  instance_type                 = var.nat_instance_type
  ssh_key_name                  = var.ec2_key_name
  ssh_allowed_cidrs             = var.ssh_allowed_cidrs
  common_tags                   = local.common_tags
}
