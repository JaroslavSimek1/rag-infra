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

### 4. Keycloak — Správa uživatelů

Autentizace je řešena přes **Keycloak** (OIDC/OAuth2). Při prvním spuštění se automaticky importuje realm `rag` s výchozími uživateli:

| Uživatel | Heslo   | Role    |
| -------- | ------- | ------- |
| `admin`  | `admin` | `admin` |
| `user`   | `user`  | `user`  |

> **Důležité:** Po prvním nasazení změňte hesla v Keycloak admin konzoli!

#### Přístup do Keycloak admin konzole

```
http://<server-ip>:8080/admin/
```

Přihlášení: `kcadmin` / `kcadmin`

#### Správa uživatelů

1. Otevřete Keycloak admin konzoli → Realm `rag` → **Users**
2. Pro vytvoření nového uživatele: **Add user** → vyplňte username → **Save**
3. Přejděte na záložku **Credentials** → nastavte heslo
4. Přejděte na záložku **Role mapping** → přiřaďte roli `admin` nebo `user`

#### Role

- **admin** — plný přístup (ingestion, správa zdrojů, jobs)
- **user** — pouze vyhledávání (`/api/search`)

> Bez přihlášení je přístupný pouze endpoint `/api/search`. Všechny admin funkce vyžadují přihlášení s rolí `admin`.

### 5. Keycloak na produkčním serveru

Pokud server běží na jiné adrese než `localhost`, nastavte env proměnnou před spuštěním:

```bash
export KEYCLOAK_PUBLIC_URL=http://<server-ip>:8080
docker compose -f docker-compose.prod.yaml up -d
```

Tato URL musí odpovídat adrese, ze které prohlížeč přistupuje ke Keycloaku (issuer v JWT tokenu).

### 6. Ověření

Po startu:

- **Frontend**: `http://<server-ip>`
- **Backend API**: `http://<server-ip>:8000/docs`
- **Keycloak**: `http://<server-ip>:8080`
- **Firecrawl**: `http://<server-ip>:3002`

---

## Periodicita stahování (Scheduler)

Systém obsahuje vestavěný scheduler, který automaticky spouští ingestion pro zdroje s nastaveným intervalem. Interval se nastavuje při vytváření ingest jobu přes dropdown "Auto Schedule" ve frontendu, nebo přes API:

```bash
# Nastavení denního scheduleru pro source s ID 1
curl -X PUT http://<server-ip>:8000/api/sources/1/schedule \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"schedule": "daily"}'
```

Dostupné intervaly: `hourly`, `daily`, `weekly`, `monthly`.

Scheduler běží automaticky na pozadí backendu a kontroluje zdroje každých 60 sekund.

---

## HTTPS (volitelné)

Pro produkční nasazení s HTTPS:

### 1. Vygeneruj certifikáty

Pro self-signed (testování):

```bash
cd rag-infra/ssl
./generate-certs.sh rag.yourdomain.com
```

Pro produkci použij certifikáty od Let's Encrypt nebo jiné CA a umísti je jako `ssl/fullchain.pem` a `ssl/privkey.pem`.

### 2. Přepni nginx na SSL konfiguraci

```bash
# Ve frontendu nahraď nginx.conf SSL verzí
cp ../rag-frontend/nginx-ssl.conf ../rag-frontend/nginx.conf
```

### 3. Uprav docker-compose.prod.yaml

Odkomentuj SSL řádky u frontend služby:

```yaml
frontend:
  ports:
    - "80:80"
    - "443:443"        # ← odkomentovat
  volumes:
    - ./ssl:/etc/nginx/ssl:ro  # ← odkomentovat
```

### 4. Restartuj frontend

```bash
docker compose -f docker-compose.prod.yaml up -d --build frontend
```

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

| Proměnná             | Hodnota v prod compose                                 | Popis                                    |
| -------------------- | ------------------------------------------------------ | ---------------------------------------- |
| `DATABASE_URL`       | `postgresql://raguser:ragpassword@postgres:5432/ragdb` | PostgreSQL                               |
| `QDRANT_HOST`        | `qdrant`                                               | Vector DB                                |
| `FIRECRAWL_URL`      | `http://firecrawl-api:3002`                            | Firecrawl engine                         |
| `OLLAMA_URL`         | `http://host.docker.internal:11434`                    | Lokální Ollama                           |
| `KEYCLOAK_URL`       | `http://keycloak:8080`                                 | Interní URL Keycloaku (Docker síť)       |
| `KEYCLOAK_PUBLIC_URL`| `http://localhost:8080`                                | Veřejná URL Keycloaku (z prohlížeče)     |
| `KEYCLOAK_REALM`     | `rag`                                                  | Keycloak realm                           |

> **Bezpečnost pro produkci:**
> - Změňte `ragpassword` v `docker-compose.prod.yaml` na bezpečné heslo
> - Změňte výchozí hesla uživatelů v Keycloak admin konzoli
> - Změňte heslo Keycloak admin účtu (`kcadmin`)
> - Zapněte HTTPS (viz sekce výše)
> - Na produkci použijte `start` místo `start-dev` v Keycloak command
