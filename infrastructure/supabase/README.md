# Supabase Database Migrations & Schemas

This directory contains production database migration scripts, seed data, and Row-Level Security (RLS) policies for the two isolated Supabase projects.

## Project Segregation
- `hinopt-core/`: Migrations for HINOPT master licensing, client tenant registry, device cryptographic keys, and system audit logs. Starts with **zero demo clients and zero demo screens**.
- `client-ads/`: Migrations for client advertising operations (e.g. for Admobitics or any advertising company client): advertisers, campaigns, day-parts, playlists, and proof-of-play reports. Starts with **zero demo campaigns and zero demo advertisers**.
