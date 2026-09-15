variable "namespace" {
  description = "Namespace where KEDA is installed"
  type        = string
  default     = "keda"
}

variable "chart_version" {
  description = "KEDA Helm chart version"
  type        = string
  default     = "2.20.2"
}