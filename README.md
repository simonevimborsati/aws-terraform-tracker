# 🚀 Serverless Visitor Counter (AWS + Terraform)

Progetto di infrastruttura Cloud Serverless sviluppato interamente tramite **Terraform** (Infrastructure as Code). L'applicazione traccia le visite degli utenti in tempo reale registrando gli eventi su un database NoSQL.

---

## 📐 Schema Architetturale

```mermaid
flowchart LR
    Client[🌐 Browser / Utente] -->|1. Richiesta HTTP POST| API[🔌 API Gateway]
    API -->|2. Invocazione| Lambda[⚡ AWS Lambda]
    Lambda -->|3. Scrittura Evento/UUID| DB[(🗄️ DynamoDB)]
    Client <--|HTTP 200 OK + UUID| API
    
    subgraph Frontend
        S3[📦 AWS S3 Static Bucket]
    end
    Client -.->|Scarica index.html| S3 
 ```