---
paths:
  - "**/*.test.*"
  - "**/*.spec.*"
  - "**/tests/**"
  - "**/__tests__/**"
  - "**/test_*"
---

# Testing rules

- Tests verify actual behavior. Don't test implementation details
- Test names state clearly "what" should "do what"
- Mock minimally — external dependencies only
- One assertion per test (complex cases excepted)
- Test data stays self-contained within the test. Don't depend on global state
