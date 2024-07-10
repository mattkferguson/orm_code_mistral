## Copyright (c) 2023, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.10.0"
    }
  }
  required_version = "= 1.2.9"
}

variable "compartment_ocid" {}


variable "apikeyval" {
  type        = string
  description = "The API key value for accessing the model"
  sensitive   = true
}

# 
variable "vcn_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "vm_display_name" {
  type    = string
  default = "A10-GPU"
}

variable "ssh_public_key" {
  type    = string
  default = ""
}

variable "ad" {
  type    = string
  default = ""
}

variable "model" {
  type        = string
  description = "Choose the model type"
  default     = "Mistral-7B-v0.1 || Mistral-7B-Instruct-v0.2"
  validation {
    condition     = var.model == "Mistral-7B-v0.1" || var.model == "Mistral-7B-Instruct-v0.2"
    error_message = "Invalid model type. Allowed values are 'Mistral-7B-v0.1' or 'Mistral-7B-Instruct-v0.2'."
  }
}
