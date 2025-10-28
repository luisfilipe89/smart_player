import express from 'express';
import { scrapeEvents } from './scraper.js';
import admin from 'firebase-admin';

const PORT = process.env.PORT || 8080;
const DATABASE_URL = process.env.DATABASE_URL;
const SERVICE_ACCOUNT = process.env.GOOGLE_APPLICATION_CREDENTIALS;

if (!DATABASE_URL) {
    console.warn('DATABASE_URL not set. Will not persist to RTDB.');
}

if (!admin.apps.length && DATABASE_URL) {
    admin.initializeApp({
        databaseURL: DATABASE_URL,
    });
}

const app = express();

app.get('/health', (_req, res) => {
    res.json({ ok: true });
});

app.post('/scrape', async (_req, res) => {
    try {
        const events = await scrapeEvents();

        if (DATABASE_URL) {
            const db = admin.database();
            await db.ref('events/latest').set({
                events,
                lastUpdated: Date.now(),
            });
        }

        res.json({ success: true, count: events.length });
    } catch (e: any) {
        console.error('Scrape error:', e);
        res.status(500).json({ success: false, error: e?.message || 'Unknown error' });
    }
});

app.listen(PORT, () => {
    console.log(`Scraper service listening on :${PORT}`);
    if (!SERVICE_ACCOUNT) {
        console.warn('GOOGLE_APPLICATION_CREDENTIALS not set; ensure Workload Identity or Service Account is attached in Cloud Run.');
    }
});





