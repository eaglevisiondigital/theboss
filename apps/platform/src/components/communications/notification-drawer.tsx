"use client";
import Link from "next/link";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import type { NotificationData } from "@/lib/notifications/contracts";
import { CommunicationActionForm } from "./action-form";
import { NotificationCard } from "./notification-center";
export function NotificationDrawer({ data }: { data: NotificationData }) {
  const dialog = useRef<HTMLDialogElement>(null), trigger = useRef<HTMLButtonElement>(null), heading = useRef<HTMLHeadingElement>(null), [open, setOpen] = useState(false), router = useRouter();
  if (data.unavailable || !data.availability.in_app || data.features.notifications === false || data.features.in_app_notifications === false) return null;
  function show() { dialog.current?.showModal(); setOpen(true); heading.current?.focus(); router.refresh(); }
  function close() { dialog.current?.close(); setOpen(false); trigger.current?.focus(); }
  return <div className="notification-drawer-trigger"><button type="button" className="button button-small button-outline" ref={trigger} aria-haspopup="dialog" aria-controls="boss-notification-drawer" aria-expanded={open} onClick={show}>Notifications{data.unread_count > 0 && <span className="notification-count" aria-label={`${data.unread_count} unread notifications`}>{data.unread_count}</span>}</button><dialog id="boss-notification-drawer" className="notification-drawer communications-console" ref={dialog} aria-labelledby="boss-notification-heading" onCancel={event => { event.preventDefault(); close(); }} onClose={() => { setOpen(false); trigger.current?.focus(); }}><header className="notification-drawer-heading"><h2 id="boss-notification-heading" tabIndex={-1} ref={heading}>Notifications</h2><button type="button" className="button button-outline" onClick={close}>Close</button></header><p className="communication-helper">{data.unread_count} unread</p>{data.unread_count > 0 && data.operations.includes("notification.read_all") && <CommunicationActionForm notifications label="Mark all read" build={() => ({ operation: "notification.read_all", input: {} })} />}<div className="notification-list">{data.notifications.length ? data.notifications.slice(0, 5).map(notification => <NotificationCard key={notification.id} notification={notification} canRead={data.operations.includes("notification.read")} />) : <p className="communication-empty">You are caught up.</p>}</div><Link className="button button-primary" href="/app/notifications" onClick={close}>View all notifications</Link></dialog></div>;
}
