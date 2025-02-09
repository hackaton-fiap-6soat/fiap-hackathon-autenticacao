
resource "aws_cognito_user_pool" "user_pool" {
    name = "user-pool"

    password_policy {
        minimum_length = 8
    }

    auto_verified_attributes = ["email"]

    username_attributes = [ "email" ]
}

resource "aws_cognito_user_pool_client" "user_pool_client" {
    name = "user-pool-client"
    user_pool_id = aws_cognito_user_pool.user_pool.id
    generate_secret = true

       
    allowed_oauth_flows_user_pool_client = true
    allowed_oauth_flows                  = ["code"]
    allowed_oauth_scopes                 = ["email", "openid"]

    callback_urls = ["http://localhost:3000"]
    logout_urls   = ["http://localhost:3000/logout"]
    
    explicit_auth_flows = [ "ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]

    supported_identity_providers = ["COGNITO"]
    access_token_validity = 60
    id_token_validity = 60
    refresh_token_validity = 10
    
    token_validity_units {
      access_token = "minutes"
      id_token = "minutes"
      refresh_token = "days"
    }
}

resource "random_string" "cognito_domain_id" {
  length  = 8
  special = false
  upper   = false
  numeric  = false
}

resource aws_cognito_user_pool_domain "user_pool_domain" {
    domain = "fiap-hackathon-authentication-${random_string.cognito_domain_id.result}"
    user_pool_id = aws_cognito_user_pool.user_pool.id
}
