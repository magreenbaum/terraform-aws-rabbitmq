# Rules and other tflint configuration that should always be used.

rule "terraform_unused_declarations" {
  enabled = true
}

plugin "aws" {
  enabled = true
  version = "0.16.1"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
