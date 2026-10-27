variable "region" {
  description = "Región de AWS (Learner Lab: us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Prefijo para los nombres de los recursos"
  type        = string
  default     = "fh"
}

variable "vpc_cidr" {
  description = "Rango de IPs de la VPC"
  type        = string
  default     = "10.40.0.0/16"
}

variable "instance_profile" {
  description = "Rol de las instancias. En Learner Lab no se pueden crear roles: se usa el que ya existe"
  type        = string
  default     = "LabInstanceProfile"
}

variable "nat_instance_type" {
  description = "Tamaño de la instancia NAT (nano = lo más barato)"
  type        = string
  default     = "t3.nano"
}

# ---------------- Máquinas Windows (clúster) ----------------
variable "key_name" {
  description = "Par de claves para descifrar la contraseña de Administrator (Learner Lab: vockey)"
  type        = string
  default     = "vockey"
}

variable "dc_instance_type" {
  description = "DC1: AD + DNS + testigo. 2 GB bastan"
  type        = string
  default     = "t3.small"
}

variable "sql_instance_type" {
  description = "SQL1 y SQL2: 4 GB (SQL Server limitado a 2 GB)"
  type        = string
  default     = "t3.medium"
}

variable "windows_running" {
  description = "true = encendidas · false = Terraform las APAGA (no las borra, se conserva todo)"
  type        = bool
  default     = true
}

variable "windows_lab" {
  description = "Crear las máquinas Windows de ensayo del clúster en AWS (DC1, SQL1, SQL2). Desde el 16 oct el clúster va en local"
  type        = bool
  default     = false
}
