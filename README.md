# Infraestrutura para autenticação e autorização do sistema

Este repositório contém o script terraform responsável por subir os serviços necessários para autenticação dos usuários e exposição das apis externamente.

Os serviços criados consistem de:

- User Pool do Amazon Cognito: Para gestão dos usuários
- Client do User Pool: Disponibiliznado a interface de cadastro e login
- Domínio do Client do User Pool: Requerimento para fazer o client acessível publicamente

- HTTP Api do Api Gateway: Para registrar serviços que serão expostos
- Stage da HTTP Api: Requerimento para publicação das apis


# Instruções para integração com outros serviços
## Integração de Lambda com o Api Gateway

Para expor uma Lambda function através do Api Gateway é necessário adicionar os seguintes resources do terraform:

```terraform

# Data source da region do AWS onde os recursos serão implementados
data "aws_region" "current" {}


# Data sources para buscar a api criada por este repositório com o nome de "api_gw_api"
data aws_apigatewayv2_apis apis {
  name = "api_gw_api"
}
data aws_apigatewayv2_api api {
  api_id = one(data.aws_apigatewayv2_apis.apis.ids)
}


# Data sources para buscar o "User Pool Client" do Amazon Cognito a ser utilizado na autenticação do endpoint
# O valor fornecido ao user_pool_id também pode ser utilizado como environment variable das Lambda functions caso seja necessário acessar a api do Amazon Cognito (por exemplo para obter o email dos usuários)
data aws_cognito_user_pools user_pools {
  name = "user-pool"
}
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


# Authorizer para autenticação das requests com Amazon Cognito:
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


# Integração do Api Gateway com Lambda
resource "aws_apigatewayv2_integration" "apigw_lambda_integration" {
  api_id             = data.aws_apigatewayv2_api.api.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.lambda.invoke_arn # Apontar para o recurso da lambda que será integrada
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "apigw_lambda_api_route" {
  api_id    = data.aws_apigatewayv2_api.api.id
  route_key = "ANY /upload"
  target    = "integrations/${aws_apigatewayv2_integration.apigw_lambda_integration.id}"
  
  ## Integração do authorizer
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito_authorizer.id
}

resource "aws_lambda_permission" "apigw_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name # Apontar para o recurso da lambda que será integrada
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${data.aws_apigatewayv2_api.api.execution_arn}/*"
}
```

Após isso o token JWT que identifica o usuário estará presente no parâmetro `event` do handler da Lambda function. Abaixo um exemplo da estrutura esperada para uma function escrita em python:

```python

{
   'version': '2.0',
   'routeKey': 'GET /endpoint',
   'rawPath': '/endpoint',
   'rawQueryString': '',
   'headers': {
      'accept': '*/*',
      'authorization': 'Bearer <token>',
      'content-length': '0',
      'content-type': 'application/json',
      'host': '<api-gateway-endpoint>',
      'user-agent': 'curl/7.68.0',
      'x-amzn-trace-id': '',
      'x-forwarded-for': '',
      'x-forwarded-port': '443',
      'x-forwarded-proto': 'https'
   },
   'requestContext': {
      'accountId': '',
      'apiId': '',
      'authorizer': {
         'jwt': {
            'claims': {
               'auth_time': '',
               'client_id': '<client-id>',
               'event_id': '<event-id>',
               'exp': '',
               'iat': '',
               'iss': '<cognito-endpoint>',
               'jti': '',
               'origin_jti': '',
               'scope': 'aws.cognito.signin.user.admin',
               'sub': '',
               'token_use': 'access',
               'username': '<cognito-username>'
            },
            'scopes': None
         }
      },
      'domainName': '',
      'domainPrefix': '',
      'http': {
         'method': 'GET',
         'path': '/endpoint',
         'protocol': 'HTTP/1.1',
         'sourceIp': '',
         'userAgent': 'curl/7.68.0'
      },
         'requestId': '',
         'routeKey': 'GET /endpoint',
         'stage': '$default',
         'time': '16/Jan/2025:00:18:08 +0000',
         'timeEpoch': 1736986688945
   },
   'isBase64Encoded': False
}
```

## Acessando usuários do api Amazon Cognito de serviços internos

Os dados dos usuários registrados no Amazon Cognito podem ser acessados através de sua api. Para isso é necessário ter em mãos o `username` do usuário e o `user_pool_id` da User Pool ao qual foi registrado.

O `user_pool_id` pode ser obtido pelo terraform através do data source à seguir. Durante a implementação da Lambda podemos assinalá-lo como variável de ambiente para que a api seja acessível.

```
# Data sources para buscar o "User Pool Client" do Amazon Cognito a ser utilizado na autenticação do endpoint
# O valor fornecido ao user_pool_id também pode ser utilizado como environment variable das Lambda functions caso seja necessário acessar a api do Amazon Cognito (por exemplo para obter o email dos usuários)
data aws_cognito_user_pools user_pools {
  name = "user-pool"
}
data aws_cognito_user_pool user_pool {
  user_pool_id = data.aws_cognito_user_pools.user_pools.ids[0]
}

# Exemplo de Lambda function
resource "aws_lambda_function" "hello_lambda" {
  filename         = "${path.module}/hello.py.zip"
  function_name    = "hello_lambda"
  role             = data.aws_iam_role.LabRole.arn
  handler          = "main.lambda_handler"
  runtime          = "python3.9"
  timeout          = 10

  environment {
    variables = {
      user_pool_id: data.aws_cognito_user_pool.user_pool.id
    }
  }
}
```

Exemplo de código python para acessar os dados de usuário:

```python
user_pool_id = os.environ.get("user_pool_id")

cognito = boto3.client("cognito-idp")
user = cognito.admin_get_user(UserPoolId=user_pool_id, Username=username)
```

Exemplo da estrutura do dict retornado pelo `admin_get_user`

```python
{
  'Username': '<username>',
  'UserAttributes': [
    {'Name': 'email', 'Value': '<user email>'},
    {'Name': 'email_verified', 'Value': 'true'},
    {'Name': 'sub', 'Value': '<username>'}
  ],
  'ResponseMetadata': {
    'RequestId': '7f0e1429-0f7c-4f3d-9311-b9fd3afa46f0',
    'HTTPStatusCode': 200,
    'HTTPHeaders': {
      'date': 'Sun, 26 Jan 2025 19:50:11 GMT',
      'content-type': 'application/x-amz-json-1.1',
      'content-length': '234',
      'connection': 'keep-alive',
      'x-amzn-requestid': '7f0e1429-0f7c-4f3d-9311-b9fd3afa46f0'
    },
    'RetryAttempts': 0
  }
}
```