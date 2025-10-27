Cloud Run Scraper (Playwright)

Overview
- Scrapes events from s-port.nl with Playwright
- Writes normalized results to Firebase Realtime Database at `events/latest`
- Exposes HTTP `/scrape` endpoint for manual or scheduled triggers

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

