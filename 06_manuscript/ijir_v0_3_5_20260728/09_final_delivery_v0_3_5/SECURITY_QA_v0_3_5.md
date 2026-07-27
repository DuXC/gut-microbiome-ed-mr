# SECURITY QA — IJIR v0.3.5

Status: **PASS**

- Working-tree text files scanned: 476
- Git revisions scanned: 27
- JWT-like or bearer-header hits in the working tree: 0
- JWT-like or bearer-header hits in selected shell/log history: 0
- JWT-like hits in committed Git history: 0
- OpenGWAS query receipt states that the JWT was not persisted: yes
- Token revocation verified: **no**

No token string, truncated token, or authentication header is reproduced in
this report. The scan covered repository text, Git history, selected
operational logs and shell histories, environment/configuration text,
notebooks, receipts, and submission-associated files. The conversation
service is not exported into the repository and is not claimed as scanned.

Author action after the audit: **revoke and regenerate the OpenGWAS JWT**.
This workflow has not performed or verified revocation.
