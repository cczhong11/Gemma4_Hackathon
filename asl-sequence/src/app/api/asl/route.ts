import { NextRequest, NextResponse } from "next/server";

const HANDSPEAK_BASE = "https://www.handspeak.com";

type SearchResult = {
  signID: number;
  signName: string;
  url: string;
};

type SearchPayload = {
  word?: SearchResult;
  wordlist?: SearchResult[];
};

type WordLookup = {
  input: string;
  normalized: string;
  match?: string;
  pageUrl?: string;
  sourceVideoUrl?: string;
  videoUrl?: string;
  skipped?: boolean;
  reason?: string;
  error?: string;
};

const OMITTED_WORDS = new Set([
  "a",
  "an",
  "the",
]);

const browserHeaders = {
  "user-agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36",
  accept:
    "text/html,application/xhtml+xml,application/xml;q=0.9,application/json;q=0.8,*/*;q=0.7",
  "accept-language": "en-US,en;q=0.9",
};

function tokenize(text: string) {
  return text.match(/[a-zA-Z][a-zA-Z'-]*/g) ?? [];
}

function absoluteHandspeakUrl(path: string) {
  return new URL(path, HANDSPEAK_BASE).toString();
}

function buildProxyVideoUrl(sourceUrl: string) {
  return `/api/video?src=${encodeURIComponent(sourceUrl)}`;
}

function extractVideoUrls(html: string) {
  const matches = html.matchAll(/<video[^>]+src="([^"]+\.mp4)"/gi);
  const urls: string[] = [];
  const seen = new Set<string>();

  for (const match of matches) {
    const url = absoluteHandspeakUrl(match[1]);
    if (!seen.has(url)) {
      seen.add(url);
      urls.push(url);
    }
  }

  return urls;
}

async function isPlayableVideoUrl(url: string, pageUrl: string) {
  const response = await fetch(url, {
    headers: {
      ...browserHeaders,
      referer: pageUrl,
      range: "bytes=0-0",
      "sec-ch-ua": '"Google Chrome";v="147", "Not.A/Brand";v="8", "Chromium";v="147"',
      "sec-ch-ua-mobile": "?0",
      "sec-ch-ua-platform": '"macOS"',
    },
    cache: "no-store",
  });

  return response.ok || response.status === 206;
}

async function findPlayableVideoUrl(html: string, pageUrl: string) {
  const candidates = extractVideoUrls(html);

  for (const candidate of candidates) {
    if (await isPlayableVideoUrl(candidate, pageUrl)) {
      return candidate;
    }
  }

  return undefined;
}

async function fetchJson(url: string) {
  const response = await fetch(url, {
    headers: browserHeaders,
    cache: "no-store",
  });

  if (!response.ok) {
    throw new Error(`Handspeak search failed with ${response.status}.`);
  }

  return (await response.json()) as SearchPayload;
}

async function fetchHtml(url: string) {
  const response = await fetch(url, {
    headers: browserHeaders,
    cache: "no-store",
  });

  if (!response.ok) {
    throw new Error(`Handspeak page fetch failed with ${response.status}.`);
  }

  return response.text();
}

async function lookupWord(input: string): Promise<WordLookup> {
  const normalized = input.toLowerCase();

  if (OMITTED_WORDS.has(normalized)) {
    return {
      input,
      normalized,
      skipped: true,
      reason: "Omitted for more natural ASL phrasing.",
    };
  }

  try {
    const searchUrl = `${HANDSPEAK_BASE}/word/app/search-dict.php?q=${encodeURIComponent(normalized)}`;
    const searchPayload = await fetchJson(searchUrl);
    const bestMatch =
      searchPayload.word ??
      searchPayload.wordlist?.find(
        (entry) => entry.signName.toLowerCase() === normalized,
      ) ??
      searchPayload.wordlist?.[0];

    if (!bestMatch?.url) {
      return {
        input,
        normalized,
        error: "No Handspeak result found.",
      };
    }

    const pageUrl = absoluteHandspeakUrl(bestMatch.url);
    const html = await fetchHtml(pageUrl);
    const videoUrl = await findPlayableVideoUrl(html, pageUrl);

    if (!videoUrl) {
      return {
        input,
        normalized,
        match: bestMatch.signName,
        pageUrl,
        error: "No working MP4 found in word page HTML.",
      };
    }

    return {
      input,
      normalized,
      match: bestMatch.signName,
      pageUrl,
      sourceVideoUrl: videoUrl,
      videoUrl: buildProxyVideoUrl(videoUrl),
    };
  } catch (error) {
    return {
      input,
      normalized,
      error: error instanceof Error ? error.message : "Lookup failed.",
    };
  }
}

export async function GET(request: NextRequest) {
  const text = request.nextUrl.searchParams.get("text")?.trim() ?? "";

  if (!text) {
    return NextResponse.json(
      { error: "Missing text query parameter." },
      { status: 400 },
    );
  }

  const words = tokenize(text);

  if (!words.length) {
    return NextResponse.json(
      { error: "No searchable words found in the sentence." },
      { status: 400 },
    );
  }

  const results = await Promise.all(words.map((word) => lookupWord(word)));

  return NextResponse.json({
    text,
    words: results,
  });
}
