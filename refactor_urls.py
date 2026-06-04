import os

lib_dir = 'lib'

replacements = {
    'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app': '${ApiConstants.academicServiceBaseUrl}',
    'https://users-service-enfoenfoeduca-451053308845.us-central1.run.app': '${ApiConstants.usersServiceBaseUrl}',
    'https://auth-service-enfoenfoeduca-451053308845.europe-west1.run.app': '${ApiConstants.authServiceBaseUrl}'
}

import_statement = "import 'package:frontend_enfoeduca/api/api_constants.dart';\n"

for root, _, files in os.walk(lib_dir):
    for f in files:
        if f.endswith('.dart'):
            path = os.path.join(root, f)
            with open(path, 'r', encoding='utf-8') as file:
                content = file.read()
            
            modified = False
            new_content = content
            for url, repl in replacements.items():
                if url in new_content:
                    new_content = new_content.replace(url, repl)
                    modified = True
            
            if modified:
                # Add import if not present
                if 'api_constants.dart' not in new_content:
                    # insert after the first import or at top
                    if 'import ' in new_content:
                        new_content = new_content.replace('import ', import_statement + 'import ', 1)
                    else:
                        new_content = import_statement + new_content
                
                with open(path, 'w', encoding='utf-8') as file:
                    file.write(new_content)
                print(f'Updated {path}')
