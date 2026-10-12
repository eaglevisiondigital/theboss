"use client";

import { useSyncExternalStore } from "react";

const subscribe = () => () => {};
const clientSnapshot = () => true;
const serverSnapshot = () => false;

export function formatTimestamp(value: string, timeZone?: string) {
  const date = new Date(value);
  return Number.isFinite(date.valueOf()) ? new Intl.DateTimeFormat("en-US", {
    month: "short", day: "numeric", hour: "numeric", minute: "2-digit",
    timeZoneName: "short", ...(timeZone ? { timeZone } : {}),
  }).format(date) : "";
}

export function CommunicationTimestamp({ value }: { value: string }) {
  // SSR and first hydration use the same zone; localization follows hydration.
  const hydrated = useSyncExternalStore(subscribe, clientSnapshot, serverSnapshot);
  return <time dateTime={value}>{formatTimestamp(value, hydrated ? undefined : "UTC")}</time>;
}
