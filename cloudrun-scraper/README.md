Cloud Run Scraper (Playwright)

Overview
- Scrapes events from s-port.nl with Playwright
- Writes normalized results to Firebase Realtime Database at `events/latest`
- Exposes HTTP `/scrape` endpoint for manual or scheduled triggers

How Sport Events Are Collected

Sport events are automatically collected from www.aanbod.s-port.nl using a containerized web scraping service:

**Architecture Overview**

The scraper is containerized using Docker and deployed to Google Cloud Run as a serverless HTTP service:

1. **Docker Container**: The `Dockerfile` builds a containerized Node.js application using the official Playwright image, which includes Chromium browser dependencies. The container:
   - Installs Node.js dependencies (Express, Firebase Admin, Playwright)
   - Builds the TypeScript codebase
   - Runs an Express HTTP server that exposes a `/scrape` endpoint

2. **Data Extraction Process**: When triggered, the scraper:
   - Navigates to the activities page filtered for specific municipality and project parameters
   - Uses a headless Chromium browser (Playwright) to:
     - Load the activities page and set the locale cookie (EN/NL)
     - Scroll through the page to trigger lazy-loading of all activity cards
     - Extract structured data from each activity card: title, URL, organizer, location, target group, cost, date/time, and image
     - Parse the raw info text to extract location, target group, cost, and date/time fields
     - Identify recurring events based on date/time patterns

3. **Storage**: Processed events are written to Firebase Realtime Database at `events/latest` with separate entries for English (`events_en`) and Dutch (`events_nl`) locales

4. **Automation**: Cloud Scheduler triggers the Cloud Run service daily at 2:00 AM (Europe/Amsterdam timezone) via HTTP POST to the `/scrape` endpoint, ensuring the app always has up-to-date event information

**Deployment Flow**

1. Docker image is built from the `Dockerfile` and pushed to Google Container Registry
2. Cloud Run deploys the container as a serverless service
3. Cloud Scheduler creates a daily HTTP job that POSTs to the `/scrape` endpoint
4. The app reads from `events/latest` in Firebase, with a local JSON fallback for offline access

Local development
1) Install deps
   npm ci
2) Build
   npm run build
3) Run (requires a service account or emulator)
   npm start

Environment variables
- DATABASE_URL: Firebase RTDB URL, e.g. https://sportappdenbosch-default-rtdb.europe-west1.firebasedatabase.app
- GOOGLE_APPLICATION_CREDENTIALS: (local only) path to service account JSON

Deploy to Cloud Run
1) Build and push image (replace PROJECT_ID)
   gcloud builds submit --tag europe-west1-docker.pkg.dev/PROJECT_ID/cloud-run-scraper/sport-events:latest cloudrun-scraper
2) Deploy
   gcloud run deploy sport-events-scraper \
     --image europe-west1-docker.pkg.dev/PROJECT_ID/cloud-run-scraper/sport-events:latest \
     --region europe-west1 \
     --platform managed \
     --allow-unauthenticated \
     --set-env-vars DATABASE_URL="https://sportappdenbosch-default-rtdb.europe-west1.firebasedatabase.app"

Schedule daily run (02:00 Europe/Amsterdam)
gcloud scheduler jobs create http daily-scrape \
  --schedule="0 2 * * *" \
  --time-zone="Europe/Amsterdam" \
  --http-method=POST \
  --uri="https://REGION-PROJECT_ID.a.run.app/scrape"

Notes
- Functions `fetchSportEvents` can be left as fallback or removed
- Agenda screen already reads from `events/latest` with local fallback











