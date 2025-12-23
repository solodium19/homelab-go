variable "cloud_id" {}
variable "folder_id" {}
variable "sa_key_file" {
  type = string
}
variable "zone" {
  default = "ru-central1-d"
}
variable "workers" {
  type = list(string)
  default = [ 
    "worker1",
    "worker2"
  ]
}
variable "dns_zone" {
  type = list(string)
  default = [ 
    "grafana",
    "prom",
    "alert"
   ]
}
variable "region" {
  default = "ru_central1"
}