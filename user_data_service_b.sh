#!/bin/bash
yum update -y
yum install -y python3 python3-pip

# Install SSM Agent (usually pre-installed on Amazon Linux 2)
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Create a simple web server for service-b
cat > /home/ec2-user/service_b.py << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import json
from http import HTTPStatus

PORT = ${port}

class ServiceBHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(HTTPStatus.OK)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                'status': 'healthy',
                'service': 'service-b',
                'port': PORT
            }
            self.wfile.write(json.dumps(response).encode())
        elif self.path == '/':
            self.send_response(HTTPStatus.OK)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                'message': 'Hello from Service B!',
                'service': 'service-b',
                'port': PORT,
                'host': 'service-b.example.com'
            }
            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_response(HTTPStatus.NOT_FOUND)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                'error': 'Not Found',
                'service': 'service-b'
            }
            self.wfile.write(json.dumps(response).encode())

with socketserver.TCPServer(("", PORT), ServiceBHandler) as httpd:
    print(f"Service B serving at port {PORT}")
    httpd.serve_forever()
EOF

# Make the script executable
chmod +x /home/ec2-user/service_b.py

# Create systemd service
cat > /etc/systemd/system/service-b.service << 'EOF'
[Unit]
Description=Service B Web Server
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user
ExecStart=/usr/bin/python3 /home/ec2-user/service_b.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable service-b.service
systemctl start service-b.service