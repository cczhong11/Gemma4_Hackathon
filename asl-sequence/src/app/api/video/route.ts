import { NextRequest, NextResponse } from "next/server";

const browserHeaders = {
  "user-agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36",
  accept: "*/*",
  "accept-language": "en-US,en;q=0.9",
  "sec-ch-ua": '"Google Chrome";v="147", "Not.A/Brand";v="8", "Chromium";v="147"',
  "sec-ch-ua-mobile": "?0",
  "sec-ch-ua-platform": '"macOS"',
};

function isAllowedHandspeakUrl(src: string) {
  try {
    const url = new URL(src);
    return url.protocol === "https:" && url.hostname === "www.handspeak.com";
  } catch {
    return false;
  }
}

export async function GET(request: NextRequest) {
  const src = request.nextUrl.searchParams.get("src");

  if (!src || !isAllowedHandspeakUrl(src)) {
    return NextResponse.json(
      { error: "Invalid or missing Handspeak source URL." },
      { status: 400 },
    );
  }

  const headers = new Headers(browserHeaders);
  headers.set("referer", src);

  const range = request.headers.get("range");
  if (range) {
    headers.set("range", range);
  }

  const upstream = await fetch(src, {
    headers,
    cache: "no-store",
  });

  if (!upstream.ok && upstream.status !== 206) {
    return NextResponse.json(
      { error: `Handspeak video fetch failed with ${upstream.status}.` },
      { status: upstream.status },
    );
  }

  const responseHeaders = new Headers();
  const passThroughHeaders = [
    "accept-ranges",
    "cache-control",
    "content-length",
    "content-range",
    "content-type",
    "etag",
    "expires",
    "last-modified",
  ];

  for (const headerName of passThroughHeaders) {
    const value = upstream.headers.get(headerName);
    if (value) {
      responseHeaders.set(headerName, value);
    }
  }

  responseHeaders.set("content-disposition", "inline");

  return new NextResponse(upstream.body, {
    status: upstream.status,
    headers: responseHeaders,
  });
}
