variable "env" { type = string }
variable "repo_name" { 
    type = string
    default = "app" 
    }
variable "image_tag_mutability" { 
    type = string
    default = "MUTABLE" 
    }
