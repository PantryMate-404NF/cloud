variable "name_prefix" {
  description = "Prefix used for resource names."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC containing the NAT instances."
  type        = string
}

variable "public_subnet_ids_by_az" {
  description = "Map of availability zone to public subnet ID."
  type        = map(string)
}

variable "private_route_table_ids_by_az" {
  description = "Map of availability zone to private route table ID."
  type        = map(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs allowed to forward traffic through the NAT instances."
  type        = set(string)
}

variable "instance_type" {
  description = "EC2 instance type for each NAT instance."
  type        = string
}

variable "ssh_key_name" {
  description = "Name of the existing EC2 Key Pair used for SSH access."
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "IPv4 /32 CIDRs allowed to SSH to the NAT instances."
  type        = set(string)
}

variable "ami_ssm_parameter_name" {
  description = "Canonical public SSM parameter that resolves to the current Ubuntu 24.04 LTS amd64 AMI."
  type        = string
  default     = "/aws/service/canonical/ubuntu/server/noble/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

variable "ami_owner_id" {
  description = "AWS account ID that must own the resolved Ubuntu AMI."
  type        = string
  default     = "099720109477"
}

variable "root_volume_size" {
  description = "NAT instance root volume size in GiB."
  type        = number
  default     = 8
}

variable "common_tags" {
  description = "Tags applied to resources that support tags."
  type        = map(string)
  default     = {}
}

variable "egress_rules" {
  description = "Protocols and ports the NAT instance may forward to the internet, keyed by rule name."
  type = map(object({
    protocol    = string
    port        = number
    description = string
  }))
  default = {
    http = {
      protocol    = "tcp"
      port        = 80
      description = "HTTP (OS package repositories)"
    }
    https = {
      protocol    = "tcp"
      port        = 443
      description = "HTTPS (AWS APIs, ECR, GitHub, Toss, Firebase, LLM, tailscale DERP)"
    }
    cloudflared_tcp = {
      protocol    = "tcp"
      port        = 7844
      description = "Cloudflare Tunnel (http2)"
    }
    cloudflared_udp = {
      protocol    = "udp"
      port        = 7844
      description = "Cloudflare Tunnel (QUIC)"
    }
    tailscale = {
      protocol    = "udp"
      port        = 41641
      description = "tailscale direct WireGuard"
    }
    tailscale_stun = {
      protocol    = "udp"
      port        = 3478
      description = "tailscale STUN"
    }
    ntp = {
      protocol    = "udp"
      port        = 123
      description = "NTP"
    }
  }
}
