1. Create an user on the Cognito user pool using the sign up page
2. Obtain the secret hash from the user by runnign the following python script:
```python
import base64, hmac, hashlib
username = 'jubelcassioverridasilva@gmail.com'
client_id = '<user-pool-client-id>'
client_secret = '<user-pool-client-secret>'
SECRET_HASH = base64.b64encode(hmac.new(bytes(client_secret, 'utf-8'), bytes(username + client_id, 'utf-8'), digestmod=hashlib.sha256).digest()).decode()
print(SECRET_HASH)
```
3. Obtain the JWT access_token for authenticating the user, set it as a env variable
```bash
export access_token=$(curl --location --request POST 'https://cognito-idp.us-east-1.amazonaws.com' \
--header 'X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth' \
--header 'Content-Type: application/x-amz-json-1.1' \
--data-raw '{
   "AuthParameters" : {
      "USERNAME" : "<user-email>",
      "PASSWORD" : "<user-password>",
      "SECRET_HASH": "<secret-hash>"
   },
   "AuthFlow" : "USER_PASSWORD_AUTH",
   "ClientId" : "<user-pool-client-id>"
}' | jq -r ".AuthenticationResult.AccessToken")
```
4. Authenticate the url to the api gateway endpoint using the access_token
```bash
curl -X GET "<api-gw-endpoint>/hello" \
   -H "Authorization: Bearer ${access_token}" \
   -H "Content-Type: application/json"

curl -X GET "<api-gw-endpoint>/goodbye" \
   -H "Authorization: Bearer ${access_token}" \
   -H "Content-Type: application/json"
```

## Lambda

payload structure for the "event" parameter on lambda's handler function
```
{
   'version': '2.0',
   'routeKey': 'GET /hello',
   'rawPath': '/hello',
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
         'path': '/hello',
         'protocol': 'HTTP/1.1',
         'sourceIp': '',
         'userAgent': 'curl/7.68.0'
      },
         'requestId': '',
         'routeKey': 'GET /hello',
         'stage': '$default',
         'time': '16/Jan/2025:00:18:08 +0000',
         'timeEpoch': 1736986688945
   },
   'isBase64Encoded': False
}
```

# S3

https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_examples_s3_cognito-bucket.html