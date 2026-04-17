import requests
import json

# ==============================================================
# الخطوة 1: ضع الـ Token الخاص بك هنا (الذي يظهر في GraphiQL)
# ==============================================================
TOKEN = "eyJhbGciOiQ" # استبدله بالتوكن الحديث

url = "http://127.0.0.1:8000/graphql/"
headers = {"Authorization": f"JWT {TOKEN}"}

# الكويري الخاص بالرفع في GraphQL
query = """
mutation uploadFile($domain: String!, $file: Upload!) {
  uploadAsset(domain: $domain, file: $file) {
    asset {
      id
      domain
      mimetype
      size
      fileUrl
    }
  }
}
"""

# المتغيرات الخاصة بالطلب (لاحظ أننا تركنا الـ file بقيمة null في البداية)
variables = {
    "domain": "HOSN", # مجال الحماية
    "file": None
}

# تكوين بنية الطلب ليتوافق مع مواصفات GraphQL Multipart Request
operations = json.dumps({"query": query, "variables": variables})
file_map = json.dumps({"0": ["variables.file"]})

# مسار الملف الذي نريد رفعه (مثال: نرفع ملف requirements.txt كمثال عملي)
file_path = "../requirements.txt"

try:
    with open(file_path, "rb") as f:
        # إرفاق الملف كالجزء "0" كما حددنا في الـ file_map
        files = {
            "0": (file_path, f, "text/plain")
        }
        
        # إرسال الطلب (POST)
        response = requests.post(
            url, 
            headers=headers, 
            data={"operations": operations, "map": file_map}, 
            files=files
        )
        
        print("======== الرد من السيرفر ========")
        print(json.dumps(response.json(), indent=2, ensure_ascii=False))

except FileNotFoundError:
    print(f"عفواً، الملف {file_path} غير موجود. الرجاء تعديل المسار لملف حقيقي.")
