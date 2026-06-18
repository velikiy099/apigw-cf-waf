# apigw-cf-waf

CloudFront + S3 でフロントエンドを配信し、`/api/*` を API Gateway に転送する構成を Terragrunt/Terraform で作るサンプルです。

認証は Cognito User Pool + Hosted UI を使います。API Gateway は Cognito User Pool Authorizer で JWT を検証します。

## 構成

```text
Browser
  -> CloudFront
       WAF: 社内 CIDR のみ allow
       /*      -> S3 frontend origin
       /api/*  -> API Gateway origin
                  Authorization header を転送
                  x-origin-verify を origin request に付与
  -> API Gateway REST API
       WAF: CloudFront published IP range かつ x-origin-verify 一致のみ allow
       Cognito User Pool Authorizer
  -> mock integration
```

このリポジトリでは、API Gateway の `execute-api` エンドポイントがインターネット到達可能であることを前提に、API Gateway 側にも WAF を付けています。

- CloudFront WAF は、正規入口を社内 CIDR に限定します。
- API Gateway WAF は、`execute-api` 直叩きを CloudFront published IP range 以外から拒否します。
- `x-origin-verify` は、自分の CloudFront distribution から来たことを補助的に確認します。
- Cognito Authorizer は、API 利用者を認証します。`x-origin-verify` はユーザー認証の代替ではありません。

詳細は [docs/security-design.md](docs/security-design.md) を参照してください。

## Repository layout

```text
.
├── README.md
├── terragrunt.hcl
├── envs/
│   └── dev/
│       └── terragrunt.hcl
├── docs/
│   └── security-design.md
└── modules/
    └── stack/
        ├── api-gateway.tf
        ├── cloudfront.tf
        ├── cognito.tf
        ├── data.tf
        ├── locals.tf
        ├── outputs.tf
        ├── s3.tf
        ├── variables.tf
        └── waf.tf
```

See also: `docs/security-design.md` for the threat model and security rationale.

## Prerequisites

- Terraform >= 1.6
- Terragrunt >= 0.55
- AWS credentials with permissions for S3, CloudFront, API Gateway, WAFv2, Cognito, IAM, and DynamoDB/S3 for remote state.

## Deploy

`envs/dev/terragrunt.hcl` の `corporate_ipv4_cidrs` を実際の社内出口 CIDR に変更してください。デフォルト値 `203.0.113.0/24` は TEST-NET-3 のプレースホルダーなので、そのままだと実利用できません。

`origin_verify_secret` は Git にコミットしないでください。以下のように環境変数で渡します。

```bash
export ORIGIN_VERIFY_SECRET=$(openssl rand -base64 32)
cd envs/dev
terragrunt init
terragrunt plan
terragrunt apply
```

apply 後、CloudFront のドメイン、Cognito Hosted UI ドメイン、SPA app client ID などが output されます。

## API call from frontend

フロントエンドは Cognito Hosted UI の Authorization Code + PKCE でログインし、取得した access token を `Authorization` ヘッダーに入れて CloudFront の `/api/*` を呼びます。

```http
GET /api/example HTTP/1.1
Host: <cloudfront-domain>
Authorization: Bearer <access_token>
```

CloudFront は API Gateway origin に転送する際に `x-origin-verify` を付与します。ブラウザ側でこのヘッダーを知る必要はありません。

## Direct API Gateway access test

通常のインターネット送信元から API Gateway invoke URL を直接叩くと、API Gateway WAF で block される想定です。

```bash
curl -i "$(terragrunt output -raw api_gateway_invoke_url)/api/example"
```

CloudFront 経由では、CloudFront WAF の社内 CIDR チェック、API Gateway WAF の CloudFront IP + `x-origin-verify` チェック、Cognito Authorizer の順で制限されます。

## Notes

### API Gateway backend

このサンプルの API Gateway は mock integration です。本番では `aws_api_gateway_integration` を Lambda proxy integration、HTTP proxy integration、private integration などに置き換えてください。

### CloudFront IP ranges

API Gateway WAF の CloudFront IP allow-list は、Terraform plan 時に `https://ip-ranges.amazonaws.com/ip-ranges.json` を読み、`service == "CLOUDFRONT"` の CIDR を WAF IP set に入れます。固定したい場合は `cloudfront_origin_facing_ipv4_cidrs_override` / `cloudfront_origin_facing_ipv6_cidrs_override` を設定してください。

### IPv6

`corporate_ipv6_cidrs` が空の場合、CloudFront IPv6 は無効化されます。IPv6 を有効にする場合は、社内 IPv6 出口 CIDR も WAF allow-list に入れてください。

### Production hardening checklist

- `origin_verify_secret` を CI secret store などから渡す。
- Terraform/Terragrunt state backend へのアクセスを厳格に制限する。
- CloudFront、AWS WAF、API Gateway の access log を有効化する。
- AWS Managed Rules の false positive を検証する。
- mock integration を実バックエンドに置き換える。
- 本番では ACM 証明書 + 独自ドメインを CloudFront に設定する。
- Hosted UI callback/logout URL を本番ドメインに更新する。
