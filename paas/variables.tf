variable "subscription_id" {
  type    = string
  default = "6b9318b1-2215-418a-b0fd-ba0832e9b333"
}

variable "resource_group_name" {
  description = "Nom du groupe de ressources Azure"
  type        = string
  default     = "rg-ncy_3"
}

variable "location" {
  description = "Région Azure"
  type        = string
  default     = "francecentral"
}

variable "environment" {
  description = "Environnement (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "app_name" {
  description = "Nom de l'application"
  type        = string
  default     = "sample-app"
}

variable "image_tag" {
  description = "Tag de l'image Docker à déployer"
  type        = string
  default     = "v1"
}

variable "app_key" {
  description = "Clé de l'app"
  type        = string
  default     = "base64:NznsPpEG1I3PeNGOZ8SGkdaMjEmcnUR5zFGtwqAI5uw="
}

variable "tenant_id" {
  description = "ID du tenant"
  type        = string
  default     = "901cb4ca-b862-4029-9306-e5cd0f6d9f86"
}
