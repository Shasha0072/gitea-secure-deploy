# Gitea Installation Guide with HTTPS (Nginx)

This guide explains how to set up Gitea with HTTPS using Nginx as a reverse proxy.

## Prerequisites

- A server running Linux (this guide uses AlmaLinux)
- Docker and Docker Compose installed
- Domain name pointing to your server (for production)
- Root or sudo access

## Installation Steps

### 1. Create Directory Structure

```bash
# Create a directory for the installation
mkdir -p ~/gitea-prod/{nginx/ssl,nginx/conf.d}
cd ~/gitea-prod
```

### 2. Create Docker Compose File

Create a `docker-compose.yml` file:

```bash
cat > docker-compose.yml << 'EOF'
version: "3.8"

networks:
  gitea:
    external: false

volumes:
  gitea-data:
  postgres-data:

services:
  server:
    image: docker.gitea.com/gitea:1.23.7
    container_name: gitea
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__database__DB_TYPE=postgres
      - GITEA__database__HOST=db:5432
      - GITEA__database__NAME=gitea
      - GITEA__database__USER=gitea
      - GITEA__database__PASSWD=YourSecurePassword
      - GITEA__server__DOMAIN=your.domain.com
      - GITEA__server__ROOT_URL=https://your.domain.com/
      - GITEA__server__SSH_DOMAIN=your.domain.com
      - GITEA__server__DISABLE_SSH=false
      - GITEA__server__SSH_PORT=22
    restart: unless-stopped
    networks:
      - gitea
    volumes:
      - gitea-data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    expose:
      - "3000"
      - "22"
    ports:
      - "222:22"  # For SSH access
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:3000/api/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    depends_on:
      - db

  db:
    image: docker.io/library/postgres:14-alpine
    container_name: gitea-db
    restart: unless-stopped
    environment:
      - POSTGRES_USER=gitea
      - POSTGRES_PASSWORD=YourSecurePassword
      - POSTGRES_DB=gitea
    networks:
      - gitea
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "gitea"]
      interval: 10s
      timeout: 5s
      retries: 5

  nginx:
    image: nginx:alpine
    container_name: gitea-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/ssl:/etc/nginx/ssl
    networks:
      - gitea
    depends_on:
      - server
EOF
```

**Important:** Replace `YourSecurePassword` with a strong password and `your.domain.com` with your actual domain.

### 3. Create Nginx Configuration

Create the Nginx configuration file:

```bash
mkdir -p nginx/conf.d
cat > nginx/conf.d/gitea.conf << 'EOF'
server {
    listen 80;
    server_name your.domain.com;
    
    # Redirect all HTTP requests to HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name your.domain.com;
    
    # SSL configuration
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
    
    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Proxy configuration
    location / {
        proxy_pass http://server:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Increase timeouts for large Git operations
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        
        client_max_body_size 100M;
    }
}
EOF
```

**Note:** Replace `your.domain.com` with your actual domain name.

### 4. SSL Certificates

#### For Development (Self-Signed)

Generate self-signed certificates for development/testing:

```bash
mkdir -p nginx/ssl
cd nginx/ssl

# Generate a private key
openssl genrsa -out key.pem 2048

# Generate a CSR (Certificate Signing Request)
openssl req -new -key key.pem -out csr.pem -subj "/CN=your.domain.com"

# Generate the certificate
openssl x509 -req -days 365 -in csr.pem -signkey key.pem -out cert.pem

# Return to the main directory
cd ../../
```

#### For Production (Let's Encrypt)

For production, you'll want to use Let's Encrypt certificates:

```bash
# Install certbot (on AlmaLinux/RHEL/CentOS)
dnf install epel-release
dnf install certbot python3-certbot-nginx

# Get certificates
certbot --nginx -d your.domain.com
```

After running certbot, update your Nginx configuration to use the Let's Encrypt certificates.

### 5. Start the Containers

```bash
# Start the services
docker-compose up -d
```

### 6. Initial Configuration

Once the containers are running, access Gitea at `https://your.domain.com` and follow the setup wizard to:

1. Create an admin account
2. Configure site settings
3. Set up other preferences

## Additional Configuration

### DNS Setup

For production use, make sure your domain name is pointed to your server's IP address.

For testing locally, add an entry to your hosts file:

```bash
echo "127.0.0.1 your.domain.com" >> /etc/hosts
```

### Firewall Configuration

Configure your firewall to allow necessary ports:

```bash
# AlmaLinux/RHEL/CentOS (using firewalld)
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-port=222/tcp  # For SSH access
firewall-cmd --reload
```

### Automatic Certificate Renewal

Add a cron job to automatically renew Let's Encrypt certificates:

```bash
echo "0 3 * * * certbot renew --quiet" | sudo tee -a /etc/crontab
```

## Maintenance

### Viewing Logs

```bash
# View all container logs
docker-compose logs -f

# View specific container logs
docker logs gitea
docker logs gitea-db
docker logs gitea-nginx
```

### Backup

Back up your Gitea data regularly:

```bash
# Create a backup directory
mkdir -p ~/gitea-backups

# Back up Gitea data
docker run --rm --volumes-from gitea -v ~/gitea-backups:/backup alpine sh -c "cd /data && tar czf /backup/gitea-data-$(date +%Y%m%d).tar.gz ."

# Back up PostgreSQL database
docker exec -t gitea-db pg_dumpall -c -U gitea | gzip > ~/gitea-backups/postgres-$(date +%Y%m%d).gz
```

### Updates

To update to a newer version of Gitea:

1. Update the image version in your docker-compose.yml file
2. Run:
   ```bash
   docker-compose pull
   docker-compose down
   docker-compose up -d
   ```

## Troubleshooting

### Check Container Status

```bash
docker-compose ps
```

### Check Nginx Configuration

```bash
docker exec -it gitea-nginx nginx -t
```

### Test Connectivity

```bash
# Test HTTP redirect
curl -I http://your.domain.com

# Test HTTPS
curl -k https://your.domain.com
```

### DNS Issues

If you're having DNS issues, verify your domain points to your server:

```bash
dig your.domain.com
```

## Security Best Practices

1. Use strong, unique passwords for database and admin accounts
2. Keep your system and containers updated
3. Regularly back up your data
4. Implement rate limiting to prevent brute force attacks
5. Consider setting up fail2ban for additional protection
6. Use the principle of least privilege for all accounts

## Resources

- [Gitea Documentation](https://docs.gitea.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Docker Documentation](https://docs.docker.com/)
