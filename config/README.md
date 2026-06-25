# Secure Database Credential Management

This folder contains encrypted database credentials using Windows DPAPI (Data Protection API).

## Security Model

- **DPAPI Encryption**: Passwords are encrypted using Windows DPAPI, which is tied to the current Windows user and machine
- **No Plain Text**: Passwords are never stored in plain text
- **User-Specific**: Only the Windows user who encrypted the credentials can decrypt them on this machine
- **Not Tracked in Git**: `db-credentials.encrypted` is in `.gitignore` (credentials never commit to repository)

## Setup

### Step 1: Encrypt Credentials (One-time setup)

```powershell
.\scripts\Encrypt-DBCredentials.ps1
```

You will be prompted to enter:
- Server name: `sql-epr-qa-eastus2.database.windows.net`
- Database name: `sqldb-epr-qa`
- Username: `db-admin@sql-epr-qa-eastus2`
- Password: `(enter your password securely)`

The script will create `config/db-credentials.encrypted` with DPAPI-encrypted credentials.

### Step 2: Connect to Database

```powershell
# Simple connection test
.\scripts\Connect-ToDatabase.ps1

# Execute a custom query
.\scripts\Connect-ToDatabase.ps1 -Query "SELECT COUNT(*) FROM sys.tables"

# Execute FK check on EPS.ADDRESS
.\scripts\Connect-ToDatabase.ps1 -Query "SELECT name FROM sys.foreign_keys WHERE OBJECT_NAME(parent_object_id) = 'ADDRESS'"
```

## Files

- **`Encrypt-DBCredentials.ps1`** — Encrypts and stores credentials
- **`Connect-ToDatabase.ps1`** — Reads encrypted credentials and connects to database
- **`db-credentials.encrypted`** — Encrypted credentials (created on first setup, NOT tracked in git)

## Security Notes

1. Only the Windows user who ran `Encrypt-DBCredentials.ps1` can decrypt the credentials
2. If you change your Windows password or move to a different machine, you'll need to re-encrypt credentials
3. Credentials file is automatically ignored in `.gitignore` — it will never be committed to git
4. DPAPI uses the Windows user account and machine key for encryption

## Troubleshooting

**"Credentials file not found"**
- Run `.\Encrypt-DBCredentials.ps1` first

**"Access Denied" when connecting**
- Verify username/password are correct
- Check Azure SQL firewall rules allow your IP
- Confirm database server and name are correct
