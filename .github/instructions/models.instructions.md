---
applyTo: "**/models.py"
---
# Database & Asset Modeling Rules
- Database Models: Do NOT suggest creating traditional relational models. Rely strictly on the `UniversalResource` model with a `JSONField` for all dynamic data.
- Storage Models: Use a generic `UniversalAsset` model for file uploads. This model must track `file` (URL/Path), `mimetype`, `size`, and `domain`.
- Authentication Models: Use a customized standard Django User model to ensure seamless JWT integration and unified auth.
- Domain Isolation: Ensure both `UniversalResource` and `UniversalAsset` models have a mandatory `owner` (ForeignKey) and `domain` (Enum) to distinguish between HOSN and SAMAM.
- Queries & Filters: When generating queries via managers, use Django 6.0 JSON lookup syntax (e.g., `data__problem='screen'`). Document expected JSON schemas in comments.