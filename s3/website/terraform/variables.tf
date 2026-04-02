variable "bucket_name" {
    type=string
    description = "Nom du bucket"
}

variable "aws_region" {
    type = string
    description = "Région AWS"
}

variable "path_file" {
    type = string
    description = "Chemin vers index.html"
}