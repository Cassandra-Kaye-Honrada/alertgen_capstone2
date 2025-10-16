# from firebase_functions import https_fn
# from firebase_admin import initialize_app
# import requests
# from urllib.parse import urlencode

# initialize_app()

# @https_fn.on_call()
# def searchFatSecret(req: https_fn.CallableRequest):
#     """
#     Callable Cloud Function to search FatSecret API
#     Call from Flutter: FirebaseFunctions.instance.httpsCallable('searchFatSecret')
#     """
    
#     query = req.data.get('query')
    
#     if not query:
#         raise https_fn.HttpsError(
#             code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
#             message='Query parameter is required'
#         )
    
#     CLIENT_ID = 'd4a960579a684e1e9d0559dc13bcfdae'
#     CLIENT_SECRET = '4a14298997b147f6987b20dbb1b85135'
    
#     try:
#         auth_url = 'https://oauth.fatsecret.com/connect/token'
#         auth_data = {
#             'grant_type': 'client_credentials',
#             'scope': 'basic',
#             'client_id': CLIENT_ID,
#             'client_secret': CLIENT_SECRET
#         }
        
#         auth_response = requests.post(
#             auth_url,
#             data=auth_data,
#             headers={'Content-Type': 'application/x-www-form-urlencoded'}
#         )
        
#         if auth_response.status_code != 200:
#             print(f'Auth failed: {auth_response.text}')
#             return {'found': False, 'error': 'Authentication failed'}
        
#         access_token = auth_response.json().get('access_token')
        
#         if not access_token:
#             return {'found': False, 'error': 'No access token received'}
        
#         search_url = 'https://platform.fatsecret.com/rest/server.api'
#         search_params = {
#             'method': 'foods.search',
#             'search_expression': query,
#             'format': 'json'
#         }
        
#         search_response = requests.get(
#             search_url,
#             params=search_params,
#             headers={'Authorization': f'Bearer {access_token}'}
#         )
        
#         if search_response.status_code != 200:
#             print(f'Search failed: {search_response.text}')
#             return {'found': False, 'error': f'Search failed with status {search_response.status_code}'}
        
#         search_data = search_response.json()
        
#         if 'error' in search_data:
#             error_msg = search_data['error'].get('message', 'Unknown error')
#             print(f'FatSecret API error: {error_msg}')
#             return {'found': False, 'error': error_msg}
        
#         if 'foods' in search_data and 'food' in search_data['foods']:
#             foods = search_data['foods']['food']
            
#             if isinstance(foods, dict):
#                 foods = [foods]
            
#             if foods:
#                 food_info = []
#                 for food in foods:
#                     name = food.get('food_name', '')
#                     description = food.get('food_description', '')
#                     food_info.append(f'{name} {description}')
                
#                 result_text = ' '.join(food_info)
#                 print(f'Found {len(foods)} foods for query: {query}')
                
#                 return {
#                     'found': True,
#                     'data': result_text,
#                     'count': len(foods)
#                 }
        
#         print(f'No foods found for query: {query}')
#         return {'found': False, 'error': 'No results found'}
        
#     except requests.exceptions.RequestException as e:
#         print(f'Network error: {str(e)}')
#         raise https_fn.HttpsError(
#             code=https_fn.FunctionsErrorCode.INTERNAL,
#             message=f'Network error: {str(e)}'
#         )
#     except Exception as e:
#         print(f'Unexpected error: {str(e)}')
#         raise https_fn.HttpsError(
#             code=https_fn.FunctionsErrorCode.INTERNAL,
#             message=f'Unexpected error: {str(e)}'
#         )