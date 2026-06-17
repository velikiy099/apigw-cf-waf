# apigw-cf-waf

Terraform/Terragrunt example for serving a private frontend from CloudFront + S3 and protecting an API Gateway REST API with CloudFront, AWS WAF, Cognito User Pool authentication, and an origin verification header.

## Architecture

```text
Browser
  -> CloudFront
       WAF: allow only corporate CIDRs
       /*      -> S3 frontend origin
       /api/*  -> API Gateway origin
                  adds x-origin-verify to origin request
                  forwards Authorization header
  -> API Gateway REST API
       Resource policy: allow CloudFront origin-facing IP ranges only
       WAF: require x-origin-verify header
       Cognito User Pool Authorizer
  -> mock integration / replace with Lambda or HTTP backend
```

The important point is that these controls have different roles:

- CloudFront WAF corporate CIDR allow-list limits the public entry point.
- API Gateway resource policy limits direct `execute-api` access to CloudFront origin-facing IP ranges.
- `x-origin-verify` identifies requests that came through this CloudFront distribution, not merely some CloudFront distribution.
- Cognito Authorizer authenticates the user. The origin verification header is not a replacement for user authentication.

## Repository layout

```text
.
├── terragrunt.hcl
├── envs/
│   └── dev/
│       └── terragrunt.hcl
└── modules/
    ├── api-gateway/
    ├── cloudfront/
    └── cognito/
```

## Prerequisites

- Terraform >= 1.6
- Terragrunt >= 0.55
- AWS credentials with permissions for S3, CloudFront, API Gateway, WAFv2, Cognito, IAM, and ACM if you later add custom domains.

## Deploy

```bash
cd envs/dev
terragrunt init
terragrunt plan
terragrunt apply
```

The example deploys without a custom domain. CloudFront's generated domain name is used as the application URL.

## Required inputs

Edit `envs/dev/terragrunt.hcl` before applying:

- `region`
- `corporate_ipv4_cidrs`
- `corporate_ipv6_cidrs` if needed
- `origin_verify_secret`

Generate the origin verification secret with something like:

```bash
openssl rand -base64 32
```

Do not commit real secrets. In production, pass it from your CI secret store or a Terragrunt include generated from a private location.

## Notes

### API Gateway direct access

Without API Gateway-side restrictions, the default `execute-api` endpoint remains reachable from the internet even when CloudFront is protected by a corporate CIDR allow-list. This repo therefore applies an API Gateway resource policy that allows only CloudFront origin-facing IP ranges.

That restriction does not prove the request came from your CloudFront distribution. A different CloudFront distribution could still be used as a source. For that reason, the API Gateway WAF also checks `x-origin-verify`.

### Fixed origin secret

`x-origin-verify` is a shared secret. It is effective only while secret. Use a high-entropy value, keep it out of logs and Git, and rotate it periodically. For rotation, temporarily allow both old and new values in WAF, update CloudFront, verify propagation, then remove the old value.

### Cognito Hosted UI

The Cognito module creates a User Pool, App Client, and Hosted UI domain. The app client uses Authorization Code Grant and has no client secret so it can be used by a browser SPA. Callback and logout URLs point at the CloudFront domain after it is known; for a production custom domain, set those URLs to your application domain instead.

## After deployment

Upload frontend files to the S3 bucket output by Terragrunt/Terraform, then access the CloudFront domain. The frontend should obtain an access token from Cognito Hosted UI and call the API with:

```http
Authorization: Bearer <access_token>
```

## Production hardening checklist

- Replace the mock API integration with Lambda, HTTP, or private integration.
- Put `origin_verify_secret` in a secret store, not in committed Terragrunt files.
- Enable CloudFront, WAF, and API Gateway access logs.
- Add AWS managed WAF rule groups after verifying false positives.
- Add rate-based WAF rules.
- Consider disabling the execute-api endpoint if you later move to a custom domain pattern that supports it cleanly.
- Use a real custom domain and ACM certificate for production CloudFront.
