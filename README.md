# Gitea IP-Based and Domain Installation

This package provides scripts for automating the installation of Gitea with HTTPS using Nginx as a reverse proxy, configured to use either your server's IP address or a custom domain name.

## Advantages of This Setup

- **Flexible Configuration**: Works with either IP addresses or domain names
- **No DNS Configuration Required**: Domain names work via hosts file entries
- **Direct Access**: Accessible from any computer with the proper hosts configuration
- **Simplified Setup**: Avoids complex DNS and domain registration
- **Secure Communication**: Full HTTPS support with self-signed certificates

## Installation Script

The `install-gitea-domain.sh` script automates the complete setup process:

- Installs prerequisites (Docker, Docker Compose, OpenSSL)
- Creates the necessary directory structure
- Generates configuration files for Docker Compose and Nginx
- Sets up self-signed SSL certificates
- Starts the containers
- Configures firewall rules (if applicable)

### Usage

```bash
chmod +x install-gitea-domain.sh
./install-gitea-domain.sh [options]
```

#### Options

| Option           | Description                                                   |
| ---------------- | ------------------------------------------------------------- |
| `-p PASSWORD`    | Database and initial admin password (default: auto-generated) |
| `-i INSTALL_DIR` | Installation directory (default: /opt/gitea)                  |
| `-s SSH_PORT`    | SSH port for Git operations (default: 222)                    |
| `-I IP_ADDRESS`  | Server IP address (default: auto-detected)                    |
| `-d DOMAIN`      | Domain name for Gitea (optional)                              |
| `-h`             | Display help and exit                                         |

### Examples

#### Basic Installation with IP Only

```bash
./install-gitea-domain.sh
```

This will:

- Detect your server's IP address automatically
- Set up Gitea with a self-signed certificate for that IP
- Auto-generate a secure database password
- Install to the default location (/opt/gitea)

#### Installation with Domain Name

```bash
./install-gitea-domain.sh -d git.yourdomain.com -I 192.168.1.100
```

This will:

- Configure Gitea to use the specified domain name
- Generate SSL certificates for the domain
- Use the specified IP address for server access
- Create instructions for hosts file configuration

#### Custom Installation with All Options

```bash
./install-gitea-domain.sh -p "SecurePassword123" -i /srv/gitea -s 2222 -I 192.168.1.100 -d git.yourdomain.com
```

This will:

- Use the specified password for the database
- Install to the custom directory `/srv/gitea`
- Configure SSH on port 2222
- Use the specified IP address
- Configure with the specified domain name

## Uninstallation Script

The `uninstall-gitea-ip.sh` script removes a Gitea installation:

- Stops and removes all containers
- Optionally removes data volumes
- Removes firewall rules
- Optionally removes the installation directory

### Usage

```bash
chmod +x uninstall-gitea-ip.sh
./uninstall-gitea-ip.sh -i /path/to/install [options]
```

#### Options

| Option           | Description                                                               |
| ---------------- | ------------------------------------------------------------------------- |
| `-i INSTALL_DIR` | Installation directory (default: /opt/gitea)                              |
| `-r`             | Remove data volumes (CAUTION: This will delete all repositories and data) |
| `-h`             | Display help and exit                                                     |

### Example

```bash
./uninstall-gitea-ip.sh -i /opt/gitea -r
```

This will completely remove the Gitea installation, including all data.

## Requirements

- Linux server with Docker and Docker Compose
- Root or sudo access
- A static or stable IP address for your server

## Post-Installation

After installation:

1. If using domain name, add an entry to your hosts file on client machines:

   ```
   192.168.1.100 git.yourdomain.com
   ```

2. Access your Gitea instance at `https://git.yourdomain.com` or `https://your-server-ip`

   - You'll need to accept the security warning about the self-signed certificate

3. Complete the initial setup wizard

4. For SSH access, use: `git@git.yourdomain.com:222` or `git@your-server-ip:222` (or the port you specified)

## Maintenance

The installation creates a README.md file in the installation directory with:

- Access information
- Database password (if auto-generated)
- Common management commands
- Backup instructions
- Hosts file configuration instructions (if using a domain)

## Security Notes

1. This setup uses self-signed certificates which will generate browser warnings
2. For production use with public domains, consider using Let's Encrypt certificates
3. The installation configures firewall rules automatically if firewalld or ufw is detected
4. Strong security headers are configured in Nginx

## Troubleshooting

If you encounter issues:

- Check container logs: `docker logs gitea`, `docker logs gitea-db`, `docker logs gitea-nginx`
- Verify that the containers are running: `docker ps`
- Check firewall rules to ensure ports 80, 443, and your SSH port are open
- Ensure your hosts file is properly configured when using domain names
- Ensure no other services are using the required ports
