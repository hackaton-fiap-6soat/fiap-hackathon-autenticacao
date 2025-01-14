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