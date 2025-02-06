import json
import boto3

def lambda_handler(event, context):
    print(event)

    if not event.get("isBase64Encoded"):
        return {
            'statusCode': 400,
            'body': json.dumps('Request must be base64 encoded')
        }
        
        
    bucket = "fiap-hackathon-acl-testing"
    # key = f'uploads/{event.get("requestContext").get("authorizer").get("jwt").get("claims").get("username")}/image.png'    
    key = "uploads/image.png"
    s3 = boto3.client('s3') 
    put_url = s3.generate_presigned_url(
        'put_object',
        Params={
            'Bucket': bucket,
            'Key': key,
            "Expires": 3600,
            "ContentType": "image/png"
        },
        HttpMethod="put"
    )

    if event.get("requestContext").get("http").get("method") == "GET":
        return {
            'statusCode': 200,
            'body': json.dumps({'upload_url': put_url})
        }
    if event.get("requestContext").get("http").get("method") == "PUT":
        return {
            'statusCode': 307,
            'headers': {
                'Location': put_url,
            }
        }
