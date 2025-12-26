---
title: SnP Backend
emoji: 🚀
colorFrom: blue
colorTo: indigo
sdk: docker
app_port: 7860
pinned: false
---

# SnP Application Backend

This space hosts the Spring Boot backend for the SnP Application.

## Configuration
- **SDK**: Docker
- **Port**: 7860 (Standard HF Space port)
- **Database**: Requires connectionstring to MongoDB Atlas (set via environment variables in Space Settings).

## Environment Variables
Set these secrets in your Space settings:
- `MONGO_URI`: Your MongoDB connection string
- `JWT_SECRET`: Secret key for JWT tokens
