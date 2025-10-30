import { chromium, Browser } from 'playwright';

type RawEvent = {
    title: string;
    url: string;
    organizer: string;
    rawInfo: string;
    imageUrl: string;
};

export type EventItem = {
    title: string;
    url: string;
    organizer: string;
    location: string;
    target_group: string;
    cost: string;
    date_time: string;
    imageUrl: string;
    isRecurring: boolean;
};

function extractInfoDict(rawText: string): {
    location: string;
    target_group: string;
    cost: string;
    date_time: string;
} {
    const lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .filter(Boolean);

    const info = {
        location: '-',
        target_group: '-',
        cost: '-',
        date_time: '-',
    };

    let current: keyof typeof info | null = null;
    for (const line of lines) {
        const lower = line.toLowerCase();
        if (lower.startsWith('locatie') || lower.startsWith('location')) current = 'location';
        else if (
            lower.startsWith('doelgroep') ||
            lower.startsWith('target group') ||
            lower.startsWith('targetgroup')
        )
            current = 'target_group';
        else if (lower.startsWith('kosten') || lower.startsWith('cost')) current = 'cost';
        else if (lower.startsWith('datum') || lower.startsWith('date')) current = 'date_time';
        else if (current) {
            if (info[current] === '-') info[current] = line;
            else info[current] += ' | ' + line;
        }
    }
    if (info.date_time !== '-') info.date_time = info.date_time.split('|')[0].trim();
    return info;
}

function isRecurringDateTime(input: string): boolean {
    const lower = input.toLowerCase();
    return !(lower.includes('1x') || lower.includes('eenmalig') || lower.includes('op inschrijving'));
}

export async function scrapeEvents(): Promise<EventItem[]> {
    let browser: Browser | undefined;
    try {
        browser = await chromium.launch({
            headless: true,
        });
        const page = await browser.newPage();
        await page.context().addCookies([
            {
                name: 'locale',
                value: 'en',
                domain: 'www.aanbod.s-port.nl',
                path: '/',
                httpOnly: false,
                secure: true,
                sameSite: 'Lax',
            },
        ]);

        await page.goto(
            'https://www.aanbod.s-port.nl/activiteiten?gemeente%5B0%5D=40&projecten%5B0%5D=5395&sort=name&order=asc',
            { waitUntil: 'networkidle' }
        );

        for (let i = 0; i < 8; i++) {
            await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
            await page.waitForTimeout(1500);
        }

        await page.waitForSelector('.activity', { timeout: 20000 });

        const raw: RawEvent[] = await page.$$eval('.activity', (cards) => {
            return cards.map((card) => {
                const titleElem = card.querySelector<HTMLAnchorElement>('h2 a');
                const imageElem = card.querySelector<HTMLImageElement>('img');
                const organizerElem = card.querySelector<HTMLSpanElement>('span.location');
                const infoElem = card.querySelector<HTMLElement>('.info');
                return {
                    title: titleElem?.textContent?.trim() || '-',
                    url: titleElem?.getAttribute('href') || '-',
                    imageUrl: imageElem?.getAttribute('src') || '',
                    organizer: organizerElem?.textContent?.trim() || '-',
                    rawInfo: infoElem?.textContent?.trim() || '',
                } as RawEvent;
            });
        });

        const processed: EventItem[] = raw.map((r) => {
            const info = extractInfoDict(r.rawInfo || '');
            const cost = info.cost.trim().replace(/^·\s*/, '').trim();
            return {
                title: r.title,
                url: r.url,
                organizer: r.organizer,
                location: info.location,
                target_group: info.target_group,
                cost,
                date_time: info.date_time,
                imageUrl: r.imageUrl,
                isRecurring: isRecurringDateTime(info.date_time),
            };
        });

        return processed;
    } finally {
        await browser?.close();
    }
}









