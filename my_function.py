import os

def validate_somthing(event, context):
    response = {}
    response['status'] = True
    response['msg'] = 'validation correct'
    return response


def not_validated(event, context):
    response = {}
    response['status'] = False
    response['msg'] = 'Validation Failed'
    return response
