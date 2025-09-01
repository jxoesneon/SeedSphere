# Auth Setup

This guide explains how to configure Magic Link email auth and OAuth providers for the SeedSphere dev server.

## Prerequisites
- Node.js 18+
- SMTP provider credentials for Magic Link
- OAuth app credentials for providers you plan to enable

## Magic Link (Email)
Set the following environment variables before starting the server:

- SMTP_HOST
- SMTP_PORT (e.g., 587)
- SMTP_USER
- SMTP_PASS
- SMTP_SECURE (optional: "true" to use TLS from the start, default "false")
- SMTP_FROM (optional, e.g., "SeedSphere <no-reply@seedsphere.local>")
- AUTH_JWT_SECRET (required, random long string)

The server will send a time-limited sign-in URL to the email you provide. The token expires in 15 minutes.

## Google OAuth
Environment variables:
- GOOGLE_CLIENT_ID
- GOOGLE_CLIENT_SECRET

Authorized redirect URI:
- http://localhost:5173/api/auth/google/callback (adjust host/port for your deployment)

## Microsoft OAuth
Environment variables:
- MS_CLIENT_ID
- MS_CLIENT_SECRET

Authorized redirect URI:
- http://localhost:5173/api/auth/microsoft/callback

## Apple OAuth
Environment variables:
- APPLE_CLIENT_ID
- APPLE_CLIENT_SECRET

Authorized redirect URI:
- http://localhost:5173/api/auth/apple/callback

Note: For Apple, you typically need to generate a JWT-based client secret from your Apple keys and team details.

## Running the server
Export the env vars and run:

```sh
AI_KMS_KEY="<base64 32 bytes>" npm run dev
```

The server will start at http://localhost:5173. Open the Configure page to test auth and key management.

## Troubleshooting
- If port 5173 is in use, terminate the process listening on that port and retry.
- Ensure AI_KMS_KEY is a valid base64-encoded 32-byte value (base64url is accepted).
