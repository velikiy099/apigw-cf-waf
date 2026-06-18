resource "aws_cognito_user_pool" "this" {
  name = "${local.name_prefix}-users"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    mutable             = true
    required            = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  tags = local.tags
}

resource "aws_cognito_resource_server" "api" {
  identifier = local.api_resource_server_identifier
  name       = "${local.name_prefix}-api"
  user_pool_id = aws_cognito_user_pool.this.id

  scope {
    scope_name        = local.api_invoke_scope_name
    scope_description = "Invoke ${local.name_prefix} API"
  }
}

resource "aws_cognito_user_pool_domain" "this" {
  domain       = local.cognito_domain
  user_pool_id = aws_cognito_user_pool.this.id
}

resource "aws_cognito_user_pool_client" "spa" {
  name         = "${local.name_prefix}-spa-client"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret                      = false
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = local.oauth_scopes
  callback_urls                        = ["https://${aws_cloudfront_distribution.app.domain_name}/callback"]
  logout_urls                          = ["https://${aws_cloudfront_distribution.app.domain_name}/"]
  supported_identity_providers         = ["COGNITO"]
  prevent_user_existence_errors        = "ENABLED"

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  depends_on = [aws_cognito_resource_server.api]
}
