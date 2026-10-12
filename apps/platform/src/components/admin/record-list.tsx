import type { AdminRecord } from "./types";

export function RecordList({ records, empty, children }: { records: AdminRecord[]; empty: string; children?: (record: AdminRecord) => React.ReactNode }) {
  if (!records.length) return <p className="empty-state">{empty}</p>;
  return (
    <div className="record-list">
      {records.map((record) => (
        <article className="record-card" key={record.id}>
          <div className="record-heading"><h3>{record.label}</h3>{record.status && <span className={`status-pill status-${record.status}`}>{record.status}</span>}</div>
          {children?.(record)}
        </article>
      ))}
    </div>
  );
}
