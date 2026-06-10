resource "aws_ssm_association" "datadog_nonprod" {

  name = aws_ssm_document.datadog_agent_install.name

  parameters = {
    DDAPIKEY    = var.datadog_api_key
    DDSITE      = var.datadog_site
    ENVIRONMENT = "non-prod"
  }

  targets {
    key    = "InstanceIds"
    values = var.nonprod_instance_ids
  }
}
