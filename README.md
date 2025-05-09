# Automated Gitea Installation with HTTPS

This package provides scripts for automating the installation and management of Gitea with HTTPS using Nginx as a reverse proxy.

## Installation Script

The `install-gitea.sh` script automates the complete setup process:

- Installs prerequisites (Docker, Docker Compose, OpenSSL, Certbot)
- Creates the necessary directory structure
- Generates configuration files for Docker Compose and Nginx
- Sets up SSL certificates (self-signed for development or Let's Encrypt for production)
- Starts the containers
- Configures firewall rules (if applicable)
- Adds local DNS entries for testing (in development mode)

### Usage

```bash
chmod +x install-gitea.sh
./install-gitea.sh -d your-domain.com [options]
```

#### Options

| Option | Description |
|--------|-------------|
| `-d DOMAIN` | Domain name for Gitea (required) |
| `-p PASSWORD` | Database and initial admin password (default: auto-generated) |
| `-e EMAIL` | Email for Let's Encrypt certificates (required for production mode) |
| `-P` | Production mode - use Let's Encrypt certificates (default: development with self-signed) |
| `-i INSTALL_DIR` | Installation directory (default: /opt/gitea) |
| `-s SSH_PORT` | SSH port for Git operations (default: 222) |
| `-h` | Display help and exit |

### Examples

#### Development Installation (with self-signed certificates)

```bash
./install-gitea.sh -d gitea.example.com -p "SecurePassword123"
```

This will:
- Set up Gitea with a self-signed certificate
- Add an entry to /etc/hosts for local testing
- Use the specified password for the database

#### Production Installation (with Let's Encrypt)

```bash
./install-gitea.sh -d gitea.example.com -e admin@example.com -P -s 2222
```

This will:
- Set up Gitea with a Let's Encrypt certificate
- Use the email address for certificate notifications
- Use port 2222 for SSH Git operations
- Auto-generate a secure database password

## Uninstallation Script

The `uninstall-gitea.sh` script removes a Gitea installation:

- Stops and removes all containers
- Optionally removes data volumes
- Removes domain entries from /etc/hosts (if specified)
- Removes crontab entries
- Optionally removes the installation directory

### Usage

```bash
chmod +x uninstall-gitea.sh
./uninstall-gitea.sh -i /path/to/install [options]
```

#### Options

| Option | Description |
|--------|-------------|
| `-i INSTALL_DIR` | Installation directory (default: /opt/gitea) |
| `-r` | Remove data volumes (CAUTION: This will delete all repositories and data) |
| `-d DOMAIN` | Domain name to remove from /etc/hosts |
| `-h` | Display help and exit |

### Example

```bash
./uninstall-gitea.sh -i /opt/gitea -r -d gitea.example.com
```

This will completely remove the Gitea installation, including all data and the domain entry in /etc/hosts.

## Requirements

- Linux server (tested on Ubuntu, Debian, RHEL, CentOS, and AlmaLinux)
- Root or sudo access
- Internet connection for downloading containers and prerequisites
- For production mode: A domain name pointing to your server's IP address

## Post-Installation

After installation:

1. Access your Gitea instance at `https://your-domain.com`
2. Complete the initial setup wizard
3. For SSH access, use: `git@your-domain.com:222` (or the port you specified)

## Maintenance

The installation creates a README.md file in the installation directory with:
- Access information
- Common management commands
- Backup instructions

## Security Notes

1. In production mode, Let's Encrypt certificates are automatically renewed
2. Firewall rules are configured if firewalld is detected
3. Strong security headers are configured in Nginx
4. For additional security, consider:
   - Setting up fail2ban
   - Implementing rate limiting
   - Regular system updates
