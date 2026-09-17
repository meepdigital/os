# Hosted Meep identity and first-login design

## Active Directory-backed first login

1. Operate a hosted Meep identity service rather than exposing an AD domain controller directly to every laptop.
2. Connect the service to Active Directory using secure LDAP/LDAPS or an identity provider that supports Kerberos, LDAP, and OIDC/SAML.
3. During installation, request the Meep tenant/server URL, organization code, and optional enrollment token. Never put a shared AD password in the image.
4. Enroll the machine with a short-lived device credential, install the CA chain, and create a local recovery administrator separately from the directory account.
5. Join the device to the domain with `realmd`/`adcli` and configure SSSD, Kerberos, PAM, NSS, and the Cinnamon display manager. Cache only an encrypted, policy-controlled offline login verifier.
6. Map directory groups to local groups and capabilities, create `/home/<user>` on first login, apply skeleton files, and set Cinnamon as the session so the same identity controls the entire UI.
7. Use MFA and device posture checks for enrollment, rotate machine secrets, and provide an emergency recovery path when the hosted service or network is unavailable.

## Meep SSO extension

Use the hosted Meep service as an OIDC identity provider or broker. Desktop applications launch an authorization-code flow with PKCE, receive short-lived scoped tokens, and use refresh tokens stored in GNOME Keyring/Secret Service. Slack, Teams, and browser-based Discord can use OIDC/SAML only if their plan and tenant support it; otherwise Meep can provide a password-manager or browser extension that fills credentials with explicit user approval. It should not silently scrape passwords or impersonate users.

## Recommended phases

- Prototype with a disposable AD/FreeIPA lab and one Ubuntu Cinnamon VM.
- Ship local login and recovery before making network login mandatory.
- Add OIDC Meep login and a token broker before attempting third-party SSO.
- Define tenant isolation, audit logs, account deletion, data residency, and outage behavior before production.

