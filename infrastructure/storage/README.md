# Cloudflare R2 Storage Configurations

This directory contains storage bucket configuration scripts, lifecycle rules, CORS definitions, and IAM policies for Cloudflare R2.

## Key Policies
- Zero public read/list permissions on the raw bucket.
- Media downloads served via signed URLs or CDN edge token validation.
- Lifecycle rule enforcing deletion of unreferenced assets after 3-day grace period.
