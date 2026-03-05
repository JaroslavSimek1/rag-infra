# RAG System — Production Deployment Guide

## Struktura Projektu

```
firecrawl-main/
├── apps/               # Firecrawl engine (beze změn)
├── services/
│   ├── backend/        # FastAPI backend
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   ├── .env.example
│   │   ├── main.py
│   │   ├── models.py
│   │   ├── ingestion.py
│   │   └── rag.py
│   └── frontend/       # React + Nginx
│       ├── Dockerfile
│       ├── nginx.conf
│       └── src/
├── k8s/                # Kubernetes manifesty
│   ├── namespace.yaml
│   ├── postgres/
│   ├── qdrant/
│   ├── backend/
│   ├── frontend/
│   └── ingress.yaml
├── docker-compose.yaml      # Lokální vývoj (Firecrawl only)
└── docker-compose.prod.yaml # Celý stack (prod / staging)
```

---

## Lokální Vývoj (stávající způsob)

```bash
# Firecrawl
docker compose up

# Backend (v rag_pipeline/ ve virtualenv)
cd rag_pipeline && source venv/bin/activate
uvicorn main:app --reload --port 8000

# Frontend
cd rag_pipeline/frontend && npm run dev
```

---

## Docker Compose (Staging / Demo)

```bash
# Spustit celý stack
docker compose -f docker-compose.prod.yaml up --build -d

# Ollama — po prvním spuštění stáhnout model
docker exec -it <ollama-container> ollama pull llama3.2

# Logy
docker compose -f docker-compose.prod.yaml logs -f backend
```

---

## Kubernetes (Produkce)

### 1. Build & Push images

```bash
docker build -t your-registry/rag-backend:latest services/backend/
docker build -t your-registry/rag-frontend:latest services/frontend/
docker push your-registry/rag-backend:latest
docker push your-registry/rag-frontend:latest
```

> Uprav `image:` v `k8s/backend/backend.yaml` a `k8s/frontend/frontend.yaml`.

### 2. Deploy

```bash
# Namespace
kubectl apply -f k8s/namespace.yaml

# Databáze (pořadí záleží)
kubectl apply -f k8s/postgres/postgres.yaml
kubectl apply -f k8s/qdrant/qdrant.yaml

# Počkat na readiness DB
kubectl wait --for=condition=ready pod -l app=postgres -n rag-system --timeout=60s

# Backend + Frontend
kubectl apply -f k8s/backend/backend.yaml
kubectl apply -f k8s/frontend/frontend.yaml

# Ingress (nutný nginx-ingress-controller)
kubectl apply -f k8s/ingress.yaml
```

### 3. Ověření

```bash
kubectl get pods -n rag-system
kubectl logs -f deployment/backend -n rag-system
```

---

## Environmentální Proměnné (Backend)

| Proměnná            | Výchozí hodnota              | Popis                                              |
| ------------------- | ---------------------------- | -------------------------------------------------- |
| `DATABASE_URL`      | `sqlite:///./rag_storage.db` | SQLite (dev) nebo PostgreSQL (prod)                |
| `QDRANT_HOST`       | `localhost`                  | Hostname Qdrant instance                           |
| `QDRANT_PORT`       | `6333`                       | Port Qdrant                                        |
| `QDRANT_LOCAL_PATH` | _(prázdné)_                  | Pokud nastaveno, používá lokální soubor místo sítě |
| `FIRECRAWL_URL`     | `http://localhost:3002`      | URL lokálního Firecrawlu                           |
| `FIRECRAWL_KEY`     | `fc-local-key`               | API klíč Firecrawlu                                |
| `OLLAMA_URL`        | `http://localhost:11434`     | URL Ollama instance                                |
| `DATA_DIR`          | `data`                       | Složka pro uložení stažených MD souborů            |

---

## TLS / HTTPS

Odkomentuj v `k8s/ingress.yaml` sekce `tls:` a `cert-manager.io/cluster-issuer:`.
Nutný nainstalovaný [cert-manager](https://cert-manager.io/).
