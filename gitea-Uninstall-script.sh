#!/bin/bash
#
# Automated Gitea Installation Script with HTTPS (Nginx)
# =====================================================
#
# This script automates the installation of Gitea with HTTPS using Nginx as a reverse proxy.
# It can be used in both development (self-signed certificates) and production (Let's Encrypt) environments.
#
# Usage:
#   ./install-gitea.sh -d example.com [-p "StrongPassword123"] [-e admin@example.com] [-P] [-i /path/to/install]
#
# Options:
#   -d DOMAIN        Domain name for Gitea (required)
#   -p PASSWORD      Database and initial admin password (default: auto-generated)
#   -e EMAIL         Email for Let's Encrypt certificates (required for production mode)
#   -P               Production mode - use Let's Encrypt certificates (default: development with self-signed)
#   -i INSTALL_DIR   Installation directory (default: /opt/gitea)
#   -s SSH_PORT      SSH port for Git operations (default: 222)
#   -h               Display this help and exit

set -e

# Default values
DOMAIN=""
DB_PASSWORD=""
EMAIL=""
PRODUCTION=false
INSTALL_DIR="/opt/gitea"
SSH_PORT=222
AUTO_PASSWORD=false

# Parse command-line options
while getopts "d:p:e:Pi:s:h" opt; do
  case ${opt} in
    d) DOMAIN=$OPTARG ;;
    p) DB_PASSWORD=$OPTARG ;;
    e) EMAIL=$OPTARG ;;
    P) PRODUCTION=true ;;
    i) INSTALL_DIR=$OPTARG ;;
    s) SSH_PORT=$OPTARG ;;
    h)
      echo "Usage: $0 -d example.com [-p \"StrongPassword123\"] [-e admin@example.com] [-P] [-i /path/to/install]"
      echo
      echo "Options:"
      echo "  -d DOMAIN        Domain name for Gitea (required)"
      echo "  -p PASSWORD      Database and initial admin password (default: auto-generated)"
      echo "  -e EMAIL         Email for Let's Encrypt certificates (required for production mode)"
      echo "  -P               Production mode - use Let's Encrypt certificates (default: development with self-signed)"
      echo "  -i INSTALL_DIR   Installation directory (default: /opt/gitea)"
      echo "  -s SSH_PORT      SSH port for Git operations (default: 222)"
      echo "  -h               Display this help and exit"
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# Validate required parameters
if [ -z "$DOMAIN" ]; then
  echo "Error: Domain name (-d) is required."
  exit 1
fi

if [ "$PRODUCTION" = true ] && [ -z "$EMAIL" ]; then
  echo "Error: Email (-e) is required for production mode with Let's Encrypt."
  exit 1
fi

# Generate random password if not provided
if [ -z "$DB_PASSWORD" ]; then
  DB_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-16)
  AUTO_PASSWORD=true
fi

# Display installation plan
echo "Gitea Installation Plan:"
echo "========================"
echo "Domain:            $DOMAIN"
if [ "$AUTO_PASSWORD" = true ]; then
  echo "Database Password: $DB_PASSWORD (auto-generated)"
else
  echo "Database Password: (as provided)"
fi
echo "Installation Dir:  $INSTALL_DIR"
echo "SSH Port:          $SSH_PORT"
if [ "$PRODUCTION" = true ]; then
  echo "Mode:              Production (Let's Encrypt)"
  echo "Email for SSL:     $EMAIL"
else
  echo "Mode:              Development (Self-signed certificates)"
fi

echo
echo "The installation will begin in 5 seconds. Press Ctrl+C to cancel."
sleep 5

# Check for required commands and install if missing
check_command() {
  if ! command -v $1 &> /dev/null; then
    echo "$1 is not installed. Installing..."
    if command -v apt-get &> /dev/null; then
      # Debian/Ubuntu
      apt-get update
      apt-get install -y $2
    elif command -v dnf &> /dev/null; then
      # RHEL/CentOS/AlmaLinux
      dnf install -y $2
    elif command -v yum &> /dev/null; then
      # Older RHEL/CentOS
      yum install -y $2
    else
      echo "Unable to install $1. Please install it manually."
      exit 1
    fi
  fi
}

# Check for Docker
check_command docker docker

# Check for Docker Compose
if ! command -v docker-compose &> /dev/null; then
  echo "Docker Compose is not installed. Installing..."
  curl -L "https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

# Check for OpenSSL
check_command openssl openssl

# If in production mode, check for certbot
if [ "$PRODUCTION" = true ]; then
  if command -v apt-get &> /dev/null; then
    # Debian/Ubuntu
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
  elif command -v dnf &> /dev/null; then
    # RHEL/CentOS/AlmaLinux
    dnf install -y epel-release
    dnf install -y certbot python3-certbot-nginx
  elif command -v yum &> /dev/null; then
    # Older RHEL/CentOS
    yum install -y epel-release
    yum install -y certbot python3-certbot-nginx
  else
    echo "Unable to install certbot. Please install it manually."
    exit 1
  fi
fi

# Create installation directory
echo "Creating installation directory..."
mkdir -p $INSTALL_DIR/{nginx/ssl,nginx/conf.d}
cd $INSTALL_DIR

# Create Docker Compose file
echo "Creating Docker Compose configuration..."
cat > docker-compose.yml << EOF
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
      - GITEA__database__PASSWD=${DB_PASSWORD}
      - GITEA__server__DOMAIN=${DOMAIN}
      - GITEA__server__ROOT_URL=https://${DOMAIN}/
      - GITEA__server__SSH_DOMAIN=${DOMAIN}
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
      - "${SSH_PORT}:22"  # For SSH access
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
      - POSTGRES_PASSWORD=${DB_PASSWORD}
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

# Create Nginx configuration
echo "Creating Nginx configuration..."
mkdir -p nginx/conf.d
cat > nginx/conf.d/gitea.conf << EOF
server {
    listen 80;
    server_name ${DOMAIN};
    
    # Redirect all HTTP requests to HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name ${DOMAIN};
    
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
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Increase timeouts for large Git operations
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        
        client_max_body_size 100M;
    }
}
EOF

# Set up SSL certificates
if [ "$PRODUCTION" = true ]; then
  echo "Setting up Let's Encrypt certificates..."
  
  # First, we need to start just the Nginx container to obtain certificates
  cat > temp-docker-compose.yml << EOF
version: "3.8"

services:
  nginx:
    image: nginx:alpine
    container_name: temp-nginx
    restart: "no"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/ssl:/etc/nginx/ssl
EOF

  # Create a temporary self-signed certificate so Nginx can start
  mkdir -p nginx/ssl
  cd nginx/ssl
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout key.pem -out cert.pem -subj "/CN=${DOMAIN}"
  cd $INSTALL_DIR

  # Start temporary Nginx
  docker-compose -f temp-docker-compose.yml up -d

  # Get Let's Encrypt certificates
  certbot certonly --webroot -w /var/www/certbot -d ${DOMAIN} --email ${EMAIL} --agree-tos --non-interactive

  # Copy certificates to Nginx folder
  cp /etc/letsencrypt/live/${DOMAIN}/fullchain.pem nginx/ssl/cert.pem
  cp /etc/letsencrypt/live/${DOMAIN}/privkey.pem nginx/ssl/key.pem

  # Stop and remove temporary Nginx
  docker-compose -f temp-docker-compose.yml down
  rm temp-docker-compose.yml

  # Add cron job for certificate renewal
  (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet && cp /etc/letsencrypt/live/${DOMAIN}/fullchain.pem ${INSTALL_DIR}/nginx/ssl/cert.pem && cp /etc/letsencrypt/live/${DOMAIN}/privkey.pem ${INSTALL_DIR}/nginx/ssl/key.pem && docker restart gitea-nginx") | crontab -
else
  echo "Generating self-signed certificates for development..."
  mkdir -p nginx/ssl
  cd nginx/ssl
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout key.pem -out cert.pem -subj "/CN=${DOMAIN}"
  cd $INSTALL_DIR
  
  # Add entry to /etc/hosts for local testing
  if ! grep -q "${DOMAIN}" /etc/hosts; then
    echo "Adding ${DOMAIN} to /etc/hosts..."
    echo "127.0.0.1 ${DOMAIN}" >> /etc/hosts
  fi
fi

# Start the containers
echo "Starting Gitea..."
docker-compose up -d

# Configure firewall if needed
if command -v firewall-cmd &> /dev/null; then
  echo "Configuring firewall..."
  firewall-cmd --permanent --add-service=http
  firewall-cmd --permanent --add-service=https
  firewall-cmd --permanent --add-port=${SSH_PORT}/tcp
  firewall-cmd --reload
fi

# Create a simple README file
cat > README.md << EOF
# Gitea Installation

## Access Information

- Gitea Web Interface: https://${DOMAIN}
- SSH Access: ssh://git@${DOMAIN}:${SSH_PORT}
- Installation Directory: ${INSTALL_DIR}
- Database Password: ${DB_PASSWORD}

## Management Commands

- View logs: \`docker-compose logs -f\`
- Restart services: \`docker-compose restart\`
- Stop services: \`docker-compose down\`
- Start services: \`docker-compose up -d\`

## Backup Commands

To backup your Gitea installation:

\`\`\`bash
# Backup Gitea data
docker run --rm --volumes-from gitea -v \$(pwd)/backups:/backup alpine sh -c "cd /data && tar czf /backup/gitea-data-\$(date +%Y%m%d).tar.gz ."

# Backup PostgreSQL database
docker exec -t gitea-db pg_dumpall -c -U gitea | gzip > \$(pwd)/backups/postgres-\$(date +%Y%m%d).gz
\`\`\`

EOF

echo ""
echo "==================================================="
echo "Gitea has been successfully installed!"
echo "==================================================="
echo ""
echo "Access your Gitea instance at: https://${DOMAIN}"
echo "SSH access port: ${SSH_PORT}"
echo ""
if [ "$AUTO_PASSWORD" = true ]; then
  echo "Database Password: ${DB_PASSWORD}"
  echo "(This password is also saved in the README.md file)"
fi
echo ""
echo "Installation details saved to: ${INSTALL_DIR}/README.md"
echo ""
if [ "$PRODUCTION" = false ]; then
  echo "This is a development installation with self-signed certificates."
  echo "You'll need to accept the security warning in your browser."
fi
echo ""
echo "When you first access Gitea, you'll be directed to the setup page"
echo "to create an admin account and configure other settings."
echo ""

exit 0
