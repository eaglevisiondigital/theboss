'use client';

import { FormEvent, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import s from '@/app/fundraising/get-started/intake.module.css';

const topics = ['Fundraising for my organization', 'Digital Money Board', 'Digital Boss Bucks cards', 'Physical Boss Bucks cards', 'Boss Bucks Discounts membership', 'Boss Bucks family account and approved expenses', 'Boss Engage / team management', 'Family Hub / combined calendars', 'Team stores and merchandise', 'Merchant partnerships', 'Sales opportunities', 'General information / help me choose'];

export default function InformationForm() {
  const router = useRouter();
  const busy = useRef(false);
  const errorRef = useRef<HTMLParagraphElement>(null);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy.current) return;
    const data = new FormData(event.currentTarget);
    const fail = (message: string) => {
      setError(message);
      requestAnimationFrame(() => errorRef.current?.focus());
    };
    setError('');
    if (!data.getAll('topics').length) {
      fail('Select at least one topic, including General information / help me choose if you’re unsure.');
      return;
    }
    const body = new URLSearchParams();
    data.forEach((value, key) => body.append(key, String(value)));
    body.set('topics', data.getAll('topics').join('; '));
    busy.current = true;
    setSending(true);
    try {
      const response = await fetch('/__forms.html', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: body.toString() });
      if (!response.ok) throw new Error('Submission failed');
      router.push('/request-information/thanks');
    } catch {
      busy.current = false;
      setSending(false);
      fail('We could not send your request. Your answers are still here. Please try again.');
    }
  }

  return <form className={s.form} name="boss-information-request" onSubmit={submit} aria-busy={sending}>
    <input type="hidden" name="form-name" value="boss-information-request" />
    <input type="hidden" name="source" value="website-request-information" />
    <p hidden><label>Leave this empty<input name="bot-field" tabIndex={-1} autoComplete="off" /></label></p>
    <p className={s.required}>Fields marked * are required.</p>
    <fieldset className={s.allFields} disabled={sending}>
      <section className={s.card}>
        <h2><span>1</span>Your contact information</h2>
        <div className={s.grid}>
          <label>First name *<input name="firstName" autoComplete="given-name" required maxLength={100} /></label>
          <label>Last name *<input name="lastName" autoComplete="family-name" required maxLength={100} /></label>
          <label>Email *<input name="email" type="email" autoComplete="email" required maxLength={254} /></label>
          <label>Phone (optional)<input name="phone" type="tel" autoComplete="tel" maxLength={40} /></label>
          <label className={s.full}>Organization / team / business (optional)<input name="organization" maxLength={200} /></label>
        </div>
      </section>
      <section className={s.card}>
        <h2><span>2</span>What would you like to learn about?</h2>
        <fieldset><legend>Select all that interest you. *</legend>
          <div className={s.choices}>{topics.map(topic => <label className={s.choice} key={topic}><input type="checkbox" name="topics" value={topic} />{topic}</label>)}</div>
        </fieldset>
        <p className={s.hint}>You can choose multiple topics. Product features and availability vary by program.</p>
      </section>
      <section className={s.card}>
        <h2><span>3</span>Your questions</h2>
        <label>Anything you’d like us to know? (optional)<textarea name="message" rows={4} maxLength={3000} /></label>
        <div className={s.bottom}>
          <div><button type="submit" disabled={sending}>{sending ? 'Sending…' : 'Request Information →'}</button><p className={s.hint}>By submitting, you’re asking The Boss team to contact you about this inquiry.</p></div>
          <aside><strong>What happens next?</strong><p>We’ll review your interests and questions, then follow up with information relevant to you.</p></aside>
        </div>
      </section>
    </fieldset>
    {error && <p className={s.error} role="alert" tabIndex={-1} ref={errorRef}>{error}</p>}
    <p role="status" aria-live="polite">{sending ? 'Sending your information request…' : ''}</p>
  </form>;
}
