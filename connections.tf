resource "aws_codestarconnections_connection" "connection" {
  name          = "${var.name[0]}-connection"
  provider_type = "GitHub" # Bitbucket, GitHub, GitHubEnterpriseServer, GitLab or GitLabSelfManaged
}