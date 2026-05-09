'use client';

import { FormEvent, useEffect, useMemo, useRef, useState } from "react";

type WordResult = {
  input: string;
  normalized: string;
  match?: string;
  pageUrl?: string;
  videoUrl?: string;
  skipped?: boolean;
  reason?: string;
  error?: string;
};

const SAMPLE = "dog cat hello";

function tokenize(text: string) {
  return text.match(/[a-zA-Z][a-zA-Z'-]*/g) ?? [];
}

export default function Home() {
  const [text, setText] = useState(SAMPLE);
  const [results, setResults] = useState<WordResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [activeIndex, setActiveIndex] = useState(0);
  const [isTeaching, setIsTeaching] = useState(true);
  const videoRef = useRef<HTMLVideoElement | null>(null);

  const available = useMemo(
    () => results.filter((item) => item.videoUrl),
    [results],
  );

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const trimmed = text.trim();

    if (!trimmed) {
      setResults([]);
      setError("Enter at least one word.");
      return;
    }

    setLoading(true);
    setError(null);
    setActiveIndex(0);

    try {
      const response = await fetch(`/api/asl?text=${encodeURIComponent(trimmed)}`);
      const payload = (await response.json()) as {
        error?: string;
        words?: WordResult[];
      };

      if (!response.ok) {
        throw new Error(payload.error ?? "Lookup failed.");
      }

      setResults(payload.words ?? []);
    } catch (lookupError) {
      setResults([]);
      setError(
        lookupError instanceof Error ? lookupError.message : "Lookup failed.",
      );
    } finally {
      setLoading(false);
    }
  }

  const resolvedIndex =
    available.length === 0 ? 0 : Math.min(activeIndex, available.length - 1);
  const current = available[resolvedIndex];
  const next = available[resolvedIndex + 1];
  const totalWords = tokenize(text).length;

  useEffect(() => {
    if (!current?.videoUrl || !isTeaching) {
      return;
    }

    const video = videoRef.current;
    if (!video) {
      return;
    }

    const playCurrent = async () => {
      try {
        video.currentTime = 0;
        await video.play();
      } catch {
        // Autoplay can be blocked until the user interacts with the page.
      }
    };

    void playCurrent();
  }, [current?.videoUrl, isTeaching]);

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-7xl flex-col gap-8 px-4 py-6 sm:px-6 lg:px-8">
      <section className="overflow-hidden rounded-[2rem] border border-line bg-panel shadow-[var(--shadow)] backdrop-blur">
        <div className="grid gap-8 p-6 lg:grid-cols-[1.1fr_0.9fr] lg:p-10">
          <div className="space-y-6">
            <p className="text-sm font-medium uppercase tracking-[0.28em] text-accent">
              Sentence to ASL video
            </p>
            <div className="space-y-3">
              <h1 className="max-w-xl text-4xl font-semibold tracking-tight sm:text-5xl">
                Type a sentence, then play the sign sequence word by word.
              </h1>
              <p className="max-w-2xl text-base leading-7 text-muted sm:text-lg">
                Each word is looked up on Handspeak, then the matching word page is
                parsed for the actual MP4 source in the HTML.
              </p>
            </div>

            <form className="space-y-4" onSubmit={handleSubmit}>
              <label className="block space-y-2">
                <span className="text-sm font-medium uppercase tracking-[0.18em] text-muted">
                  Sentence
                </span>
                <textarea
                  value={text}
                  onChange={(event) => setText(event.target.value)}
                  placeholder="Try: dog cat hello"
                  className="min-h-32 w-full rounded-[1.5rem] border border-line bg-panel-strong px-5 py-4 text-lg outline-none transition focus:border-accent focus:ring-4 focus:ring-accent/15"
                />
              </label>

              <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
                <button
                  type="submit"
                  disabled={loading}
                  className="inline-flex min-h-12 items-center justify-center rounded-full bg-accent px-6 font-semibold text-white transition hover:bg-accent-strong disabled:cursor-wait disabled:opacity-70"
                >
                  {loading ? "Looking up signs..." : "Build sequence"}
                </button>
                <button
                  type="button"
                  onClick={() => setText(SAMPLE)}
                  className="inline-flex min-h-12 items-center justify-center rounded-full border border-line px-6 font-semibold text-foreground transition hover:bg-white/50"
                >
                  Load sample
                </button>
                <p className="text-sm text-muted">
                  {totalWords} word{totalWords === 1 ? "" : "s"} detected
                </p>
              </div>
            </form>

            <p className="text-sm text-muted">
              Common filler words like `the`, `a`, and `an` are omitted so the
              sequence reads more like natural ASL.
            </p>

            {error ? (
              <div className="rounded-[1.25rem] border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                {error}
              </div>
            ) : null}
          </div>

          <div className="rounded-[1.75rem] border border-line bg-[#1a211f] p-4 text-white shadow-2xl">
            <div className="mb-3 flex items-center justify-between gap-3">
              <div>
                <p className="text-xs uppercase tracking-[0.24em] text-white/55">
                  Teaching mode
                </p>
                <p className="text-lg font-medium">
                  {current?.match ?? "No active sign yet"}
                </p>
              </div>
              <p className="text-sm text-white/60">
                {available.length ? `${resolvedIndex + 1}/${available.length}` : "0/0"}
              </p>
            </div>

            <div className="overflow-hidden rounded-[1.4rem] border border-white/10 bg-black">
              {current?.videoUrl ? (
                <video
                  key={current.videoUrl}
                  ref={videoRef}
                  src={current.videoUrl}
                  controls
                  preload="auto"
                  playsInline
                  onEnded={() => {
                    if (resolvedIndex < available.length - 1) {
                      setActiveIndex((value) => value + 1);
                    } else if (isTeaching) {
                      setActiveIndex(0);
                    }
                  }}
                  className="aspect-video w-full"
                />
              ) : (
                <div className="flex aspect-video items-center justify-center px-6 text-center text-white/65">
                  Run a lookup to load the first available sign video.
                </div>
              )}
            </div>

            {next?.videoUrl ? (
              <video
                key={`preload-${next.videoUrl}`}
                src={next.videoUrl}
                preload="auto"
                className="hidden"
                aria-hidden="true"
              />
            ) : null}

            <div className="mt-4 rounded-2xl border border-white/10 bg-white/5 px-4 py-3">
              <p className="text-xs uppercase tracking-[0.22em] text-white/50">
                Phrase coach
              </p>
              <p className="mt-1 text-sm text-white/75">
                The player moves through each word in order and loops back to the
                start so the full sentence feels like a guided signing drill.
              </p>
              <div className="mt-3 flex flex-wrap gap-2">
                <button
                  type="button"
                  onClick={() => setIsTeaching((value) => !value)}
                  className={`rounded-full px-4 py-2 text-sm font-medium transition ${
                    isTeaching
                      ? "bg-white text-black"
                      : "bg-white/10 text-white hover:bg-white/18"
                  }`}
                >
                  {isTeaching ? "Teaching loop on" : "Teaching loop off"}
                </button>
                <button
                  type="button"
                  onClick={() => setActiveIndex(0)}
                  className="rounded-full bg-white/10 px-4 py-2 text-sm font-medium text-white transition hover:bg-white/18"
                >
                  Restart sentence
                </button>
              </div>
            </div>

            <div className="mt-4 flex flex-wrap gap-2">
              {available.map((item, index) => (
                <button
                  key={`${item.input}-${index}`}
                  type="button"
                  onClick={() => setActiveIndex(index)}
                  className={`rounded-full px-3 py-2 text-sm transition ${
                    index === resolvedIndex
                      ? "bg-white text-black"
                      : "bg-white/10 text-white/80 hover:bg-white/18"
                  }`}
                >
                  {index + 1}. {item.match ?? item.input}
                </button>
              ))}
            </div>
          </div>
        </div>
      </section>

      <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {results.map((item, index) => {
          const playableIndex = available.findIndex(
            (entry) =>
              entry.input === item.input &&
              entry.normalized === item.normalized &&
              entry.videoUrl === item.videoUrl,
          );

          return (
            <article
              key={`${item.input}-${index}`}
              className="rounded-[1.5rem] border border-line bg-panel p-5 shadow-[0_12px_30px_rgba(61,45,32,0.08)] backdrop-blur"
            >
              <div className="mb-4 flex items-start justify-between gap-4">
                <div>
                  <p className="text-xs uppercase tracking-[0.2em] text-muted">
                    Input word
                  </p>
                  <h2 className="text-2xl font-semibold">{item.input}</h2>
                </div>
                <span className="rounded-full bg-black/5 px-3 py-1 text-sm text-muted">
                  {item.skipped ? "Omitted" : item.videoUrl ? "Ready" : "Missing"}
                </span>
              </div>

              <div className="space-y-2 text-sm leading-6 text-muted">
                <p>
                  Match:{" "}
                  <span className="font-medium text-foreground">
                    {item.match ?? "No dictionary match"}
                  </span>
                </p>
                <p>
                  Status:{" "}
                  <span className="font-medium text-foreground">
                    {item.reason ?? item.error ?? "Playable MP4 found"}
                  </span>
                </p>
              </div>

              <div className="mt-4 flex flex-wrap gap-3">
                {item.pageUrl ? (
                  <a
                    href={item.pageUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="rounded-full border border-line px-4 py-2 text-sm font-medium transition hover:bg-white/60"
                  >
                    Word page
                  </a>
                ) : null}
                {item.videoUrl ? (
                  <button
                    type="button"
                    onClick={() => {
                      if (playableIndex >= 0) {
                        setActiveIndex(playableIndex);
                        videoRef.current?.scrollIntoView({
                          behavior: "smooth",
                          block: "center",
                        });
                      }
                    }}
                    className="rounded-full bg-accent px-4 py-2 text-sm font-medium text-white transition hover:bg-accent-strong"
                  >
                    Play this sign
                  </button>
                ) : null}
              </div>
            </article>
          );
        })}
      </section>
    </main>
  );
}
