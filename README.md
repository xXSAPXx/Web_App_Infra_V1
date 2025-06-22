
# Project Architecture Overview:
<img src="https://github.com/user-attachments/assets/e1985e2d-49e8-4bc0-955f-d3bdd8346a18" alt="DEV_OPS PROJECT IaC vpd" width="550"/>



# Network Architecture Diagram:

This architecture describes traffic flow for the domain `www.xxsapxx.uk` which is proxied through Cloudflare in **Full TLS mode**, routed to an AWS Application Load Balancer (ALB), and forwarded to frontend and backend targets based on path rules.

```text
                                                            ALB_HTTP_LISTENER
                                                           (REDIRECTED TO HTTPS)
                                                                  |
                                                                  V
Browser -----------------> CloudFlare_Proxy -----------------> ALB_DNS -------------------> ALB_HTTPS_LISTENER
`www.xxsapxx.uk`            (FULL_TLS_MODE)                  (`AWS_TLS_CERT_WITH_ACM`)           |
                            (CNAME www -> ALB_DNS)                                               |
                                                                                                 |
                                                                                +---------------------------+
                                                                                | Path Rule: '/api/*'       | URL/*
                                                                                |                           |
                                                                                V                           V
                                                                ALB_BACKEND_TG_PORT_3000          ALB_FRONTEND_TG_PORT_80    
                                                                (HEALTH_CHECK: /backend)           (HEALTH_CHECK: /)     
