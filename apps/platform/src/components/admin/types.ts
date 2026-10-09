export type { AdminView, AdminRecord, AdminViewData } from "@/lib/admin/contracts";

export type FormOption = { value: string; label: string };
export type AdminField = {
  name: string;
  label: string;
  type?: "text" | "select" | "checkbox" | "date" | "datetime-local" | "number";
  required?: boolean;
  options?: FormOption[];
  value?: string | number | boolean | null;
  placeholder?: string;
  hint?: string;
  maxLength?: number;
  onValueChange?: (value: string) => void;
};

export type AdminCommand = {
  operation: string;
  input: Record<string, unknown>;
  ref?: string;
};
