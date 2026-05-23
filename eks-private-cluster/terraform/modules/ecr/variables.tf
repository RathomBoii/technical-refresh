variable "env" { type = string }
variable "repo_name" { 
    type = string
    default = "helloworld" 
    }
variable "image_tag_mutability" { 
    type = string
    default = "MUTABLE" 
    }
