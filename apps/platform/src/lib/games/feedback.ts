/** Classify known HTTP rejections without exposing database response details. */
export function gameFormFailureMessage(status: number) {
  if (status === 401) return "Please sign in again to continue.";
  if (status === 403) return "You do not have permission to make this game change.";
  if (status === 409) return "The game, schedule or authority changed. Refresh and review it.";
  if (status === 422) return "Review the game fields and Calendar matchup targets, then try again.";
  return "The change could not be confirmed. Retry to safely check the same request.";
}
