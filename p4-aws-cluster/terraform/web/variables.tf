variable "region" {
  description = "Región de AWS (Learner Lab: us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Prefijo de los nombres (el mismo que en base)"
  type        = string
  default     = "fh"
}

variable "instance_profile" {
  description = "Rol de las instancias. En Learner Lab no se pueden crear roles: se usa el que ya existe"
  type        = string
  default     = "LabInstanceProfile"
}

variable "web_instance_type" {
  description = "Servidores web de WordPress"
  type        = string
  default     = "t3.micro"
}

variable "web_min" {
  description = "Mínimo de servidores web (2 = uno en cada zona)"
  type        = number
  default     = 2
}

variable "web_max" {
  description = "Máximo de servidores web si sube la carga"
  type        = number
  default     = 4
}

variable "db_instance_class" {
  description = "Tamaño de la base de datos MySQL"
  type        = string
  default     = "db.t3.micro"
}

variable "db_multi_az" {
  description = "RDS Multi-AZ: réplica síncrona en otra zona con conmutación automática (clúster MySQL). false si el lab no lo permite"
  type        = bool
  default     = true
}

variable "db_name" {
  description = "Nombre de la base de datos de WordPress"
  type        = string
  default     = "wordpress"
}

variable "db_user" {
  description = "Usuario administrador de MySQL"
  type        = string
  default     = "wpadmin"
}

variable "domain_name" {
  description = "Nombre que llevará el certificado HTTPS (autofirmado en el lab)"
  type        = string
  default     = "www.furniturehouse2.com"
}
