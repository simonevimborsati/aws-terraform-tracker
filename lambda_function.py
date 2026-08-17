import json
import boto3
import os
import uuid
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('TABLE_NAME', 'visitor-tracker-table')

def lambda_handler(event, context):
    table = dynamodb.Table(table_name)
    event_id = str(uuid.uuid4())
    timestamp = datetime.utcnow().isoformat()
    
    table.put_item(
        Item={
            'event_id': event_id,
            'timestamp': timestamp,
            'source': 'terraform-demo'
        }
    )
    
    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            'Content-Type': 'application/json'
        },
        'body': json.dumps({'message': 'Visita tracciata!', 'event_id': event_id})
    }