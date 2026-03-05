# RAG System — Deployment Guide

## Předpoklady

Na server musí být nainstalovaný:

- **Docker** (≥ 24.x)
- **Docker Compose** (≥ 2.x)
- **Git**
- **16 GB RAM** doporučeno (Firecrawl build + sentence-transformers)

Ollama musí běžet **lokálně na serveru** (mimo Docker) s modelem `llama3.2`:

```bash
# Instalace Ollamy na server
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama3.2
```

---

## Deployment na školní server

### 0. Nainstaluj Ollamu a stáhni LLM model

> Ollama musí běžet přímo na serveru (mimo Docker). Toto je nutné udělat jen jednou.

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama3.2
```

Ověření že Ollama běží:

```bash
ollama list   # měl by ukázat llama3.2
```

### 1. Naklonuj repozitáře vedle sebe

```bash
mkdir projekt && cd projekt

git clone https://github.com/JaroslavSimek1/rag-infra
git clone https://github.com/JaroslavSimek1/rag-frontend
git clone https://github.com/JaroslavSimek1/rag-backend
git clone https://github.com/mendableai/firecrawl firecrawl-main
```

Výsledná struktura:

```
projekt/
├── firecrawl-main/
├── rag-backend/
├── rag-frontend/
└── rag-infra/          ← odtud spouštíme vše
```

### 2. Uprav org v docker-compose.prod.yaml

```bash
cd rag-infra
# Nahraď 'your-org' správnou org v docker-compose.prod.yaml
sed -i 's/your-org/JaroslavSimek1/g' docker-compose.prod.yaml
```

### 3. Spusť celý stack

```bash
# První spuštění — build trvá 10–20 minut
docker compose -f docker-compose.prod.yaml up --build -d

# Sleduj logy
docker compose -f docker-compose.prod.yaml logs -f backend
```

### 4. Ověření

Po startu:

- **Frontend**: `http://<server-ip>`
- **Backend API**: `http://<server-ip>:8000/docs`
- **Firecrawl**: `http://<server-ip>:3002`

---

## Update po změně kódu

Pokud tým pushne do `rag-backend` nebo `rag-frontend`, GitHub Actions automaticky pushnout nové Docker image.

Na serveru pak stačí:

```bash
cd rag-infra
docker compose -f docker-compose.prod.yaml pull backend frontend
docker compose -f docker-compose.prod.yaml up -d
```

---

## Zastavení

```bash
docker compose -f docker-compose.prod.yaml down

# Smazat i data (volumes)
docker compose -f docker-compose.prod.yaml down -v
```

---

## Env Variables (Backend)

| Proměnná        | Hodnota v prod compose                                 | Popis            |
| --------------- | ------------------------------------------------------ | ---------------- |
| `DATABASE_URL`  | `postgresql://raguser:ragpassword@postgres:5432/ragdb` | PostgreSQL       |
| `QDRANT_HOST`   | `qdrant`                                               | Vector DB        |
| `FIRECRAWL_URL` | `http://firecrawl-api:3002`                            | Firecrawl engine |
| `OLLAMA_URL`    | `http://host.docker.internal:11434`                    | Lokální Ollama   |

> **Hesla pro produkci:** Změň `ragpassword` v `docker-compose.prod.yaml` na bezpečné heslo před nasazením.
