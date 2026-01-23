variable "hcloud_token" {
  type        = string
  default     = env("HCLOUD_TOKEN")
  description = "Hetzner Cloud API token."
  validation {
    condition     = length(var.hcloud_token) > 0
    error_message = "The hcloud_token must not be empty."
  }
}
