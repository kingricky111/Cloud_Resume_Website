# Project 2: Containerized Backend (Docker)

## Overview
This project extends the Cloud Resume Challenge by introducing a **containerized backend implementation** of the visit counter API.

While Project 1 uses Azure Functions (serverless), this project demonstrates how the **same backend capability** can be packaged and run as a **containerized web service** using Docker. This mirrors real-world scenarios where systems evolve from serverless to container-based runtimes for portability and orchestration.

The containerized API connects to the **same Azure Table Storage** used by the production site, ensuring behavioral parity across deployment models.

---

## Why This Project Exists
The goal of this project is to demonstrate:

- Containerizing an existing backend capability
- Environment-based configuration using injected secrets
- Local development and testing with Docker Compose
- Runtime portability without impacting production infrastructure

This project does **not** replace the Azure Functions implementation — it exists alongside it as an alternative runtime.

---

## Tech Used
- **FastAPI (Python)**
- **Docker**
- **Docker Compose**
- **Azure Table Storage**

The containerized API exposes the same `/visits` endpoint and updates the same table used by the live website.

---

## Repository Structure
```text
backend/crc-api/api-container/
├── app.py              # FastAPI application
├── requirements.txt    # Container-specific dependencies

Infrastructure/docker/
├── dockerfile          # Container image definition
├── docker-compose.yml  # Local orchestration and env injection