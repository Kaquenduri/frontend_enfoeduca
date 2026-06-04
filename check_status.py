import os

lib_dir = 'lib'
for root, _, files in os.walk(lib_dir):
    for f in files:
        if f.endswith('.dart'):
            path = os.path.join(root, f)
            with open(path, 'r', encoding='utf-8') as file:
                content = file.read()
            has_http_import = "import 'package:http/http.dart'" in content
            has_api_client = 'ApiClient' in content
            has_api_service_import = "api_service.dart'" in content
            has_hardcoded = 'https://' in content and 'run.app' in content
            if has_http_import or has_hardcoded:
                status = []
                if has_api_client: status.append('MIGRATED_APICLIENT')
                else: status.append('PENDING_APICLIENT')
                if has_http_import: status.append('STILL_HAS_HTTP_IMPORT')
                if has_api_service_import: status.append('STILL_HAS_APISERVICE')
                if has_hardcoded: status.append('STILL_HAS_HARDCODED_URL')
                print(f'{path} -> {" | ".join(status)}')
