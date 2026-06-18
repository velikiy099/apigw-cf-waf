resource "aws_api_gateway_rest_api" "this" {
  name        = "${local.name_prefix}-api"
  description = "REST API protected by CloudFront WAF, API Gateway WAF, x-origin-verify, and Cognito."

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.tags
}

resource "aws_api_gateway_authorizer" "cognito" {
  name            = "${local.name_prefix}-cognito-authorizer"
  rest_api_id     = aws_api_gateway_rest_api.this.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [aws_cognito_user_pool.this.arn]
  identity_source = "method.request.header.Authorization"
}

resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "api"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "api_root" {
  rest_api_id          = aws_api_gateway_rest_api.this.id
  resource_id          = aws_api_gateway_resource.api.id
  http_method          = "ANY"
  authorization        = "COGNITO_USER_POOLS"
  authorizer_id        = aws_api_gateway_authorizer.cognito.id
  authorization_scopes = [local.api_invoke_scope]
}

resource "aws_api_gateway_integration" "api_root" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.api.id
  http_method = aws_api_gateway_method.api_root.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_method_response" "api_root_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.api.id
  http_method = aws_api_gateway_method.api_root.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "api_root_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.api.id
  http_method = aws_api_gateway_method.api_root.http_method
  status_code = aws_api_gateway_method_response.api_root_200.status_code

  response_templates = {
    "application/json" = jsonencode({ message = "authenticated api root" })
  }

  depends_on = [aws_api_gateway_integration.api_root]
}

resource "aws_api_gateway_method" "api_proxy" {
  rest_api_id          = aws_api_gateway_rest_api.this.id
  resource_id          = aws_api_gateway_resource.proxy.id
  http_method          = "ANY"
  authorization        = "COGNITO_USER_POOLS"
  authorizer_id        = aws_api_gateway_authorizer.cognito.id
  authorization_scopes = [local.api_invoke_scope]

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "api_proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.api_proxy.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_method_response" "api_proxy_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.api_proxy.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "api_proxy_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.api_proxy.http_method
  status_code = aws_api_gateway_method_response.api_proxy_200.status_code

  response_templates = {
    "application/json" = jsonencode({ message = "authenticated api proxy" })
  }

  depends_on = [aws_api_gateway_integration.api_proxy]
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.api.id,
      aws_api_gateway_resource.proxy.id,
      aws_api_gateway_method.api_root.id,
      aws_api_gateway_method.api_proxy.id,
      aws_api_gateway_integration.api_root.id,
      aws_api_gateway_integration.api_proxy.id,
      aws_api_gateway_authorizer.cognito.id,
      local.api_invoke_scope,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration_response.api_root_200,
    aws_api_gateway_integration_response.api_proxy_200,
  ]
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.api_stage_name

  tags = local.tags
}
