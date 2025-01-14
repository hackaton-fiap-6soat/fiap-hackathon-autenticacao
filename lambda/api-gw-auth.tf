# Pre-configured resources

## Query for apis with a given name
data aws_apigatewayv2_apis apis {
  name = "api_gw_api"
}

## Use the first api from the query
data aws_apigatewayv2_api api {
  api_id = one(data.aws_apigatewayv2_apis.apis.ids)
}


## Query for user pools with a given name
data aws_cognito_user_pools user_pools {
  name = "user-pool"
}
## Use the first user pool from the query
data aws_cognito_user_pool user_pool {
  user_pool_id = data.aws_cognito_user_pools.user_pools.ids[0]
}

data aws_cognito_user_pool_clients user_pool_clients {
  user_pool_id = data.aws_cognito_user_pool.user_pool.id
}

data aws_cognito_user_pool_client user_pool_client {
  user_pool_id = data.aws_cognito_user_pool.user_pool.id
  client_id = data.aws_cognito_user_pool_clients.user_pool_clients.client_ids[0]
}

data "aws_region" "current" {}


# Cognito Authorizer 
resource "aws_apigatewayv2_authorizer" "cognito_authorizer" {
  api_id = data.aws_apigatewayv2_api.api.id
  name = "cognito_authorizer"
  authorizer_type = "JWT"
  identity_sources = ["$request.header.Authorization"]
  jwt_configuration {
    issuer = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${data.aws_cognito_user_pool.user_pool.id}"
    audience = [data.aws_cognito_user_pool_client.user_pool_client.id]
  }
}

