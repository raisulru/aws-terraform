import os

def not_validated_input(event, context):
    response = {}
    response['status'] = False
    response['msg'] = 'Validation Failed'
    return response
