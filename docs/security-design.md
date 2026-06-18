# Security design

## Threats this example addresses

This repository treats the default API Gateway `execute-api` endpoint as internet-reachable unless explicitly restricted.

The expected access path is:

```text
corporate network
  -> CloudFront WAF corporate CIDR allow-list
  -> CloudFront /api/* behavior
  -> API Gateway WAF
  -> API Gateway Cognito User Pool Authorizer
```

A direct request such as the following bypasses CloudFront WAF unless API Gateway is also restricted:

```text
internet client
  -> https://<api-id>.execute-api.<region>.amazonaws.com/<stage>/api/...
```

Therefore this example applies API Gateway WAF rules that only allow requests when both conditions are true:

1. The source IP is in the CloudFront published IP ranges.
2. The request contains the expected `x-origin-verify` value injected by this CloudFront distribution.

The Cognito authorizer is still required. The origin verification header is not user authentication.

## Why both CloudFront IP restriction and x-origin-verify are used

The CloudFront IP allow-list is a coarse but important control. It blocks ordinary internet clients from directly reaching the `execute-api` endpoint.

The `x-origin-verify` header is a finer control. It helps distinguish your CloudFront distribution from other possible CloudFront distributions that could use the same API Gateway endpoint as their origin.

Using only a fixed header is weaker because a leaked secret would allow arbitrary internet clients to call the API Gateway endpoint directly. Using the CloudFront IP allow-list as well means a leaked secret still does not allow ordinary direct internet access.

## Secret handling

`origin_verify_secret` is a shared secret. Keep it out of Git and logs. Terraform state will contain enough information to reproduce infrastructure, so the state backend must be encrypted and access-controlled.

Recommended rotation procedure:

1. Temporarily allow both old and new header values in the API Gateway WAF rule.
2. Update CloudFront to send the new value.
3. Wait for CloudFront propagation and test.
4. Remove the old value from WAF.

The current example implements a single active value to keep the base module simple. Extend the WAF byte match condition to accept a list of values if you want zero-downtime rotation.

## IPv6 note

CloudFront IPv6 is disabled unless `corporate_ipv6_cidrs` is non-empty. This avoids an accidental bypass where IPv4 corporate CIDRs are restricted but IPv6 viewer access remains open.
