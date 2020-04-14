variable "prefix" {
  description = "This prefix will be included in the name of most resources."
}

variable "region" {
  description = "The region where the resources are created."
  default     = "us-west-2"
}

variable "address_space" {
  description = "The address space that is used by the virtual network. You can supply more than one address space. Changing this forces a new resource to be created."
  default     = "10.0.0.0/16"
}

variable "subnet_prefix" {
  description = "The address prefix to use for the subnet."
  default     = "10.0.10.0/24"
}

variable "instance_type" {
  description = "Specifies the AWS instance type."
  default     = "t2.small"
}

variable "admin_username" {
  description = "Administrator user name for mysql"
  default     = "hashicorp"
}

variable "owner" {
  description = "owner to pass to owner tag"
  default     = "Andy Assareh"
}

variable "ttl" {
  description = "Hours until instances are reaped by N.E.P.T.R"
  default     = "1"
}

variable "key_pair_name" {
  description = "The key name of the Key Pair to use for the instance"
}